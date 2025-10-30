# Docker Swarm på AWS

## 1. Skapa resurser

Jag började med att skapa nedan resurser manuellt, för att sedan skapa en CloudFormation template via IaC generator för automatisering.

- Security Group (*1)
- EC2-instanser till swarm-kluster (skapade 1 manuellt, modifierade skriptet till 3)

Skripten ligger i sin helhet under `templates/`.

### 1.1 Kör skripten i terminalen

**Security Group:**
```bash
aws cloudformation create-stack \
  --stack-name swarm-sg \
  --template-body file://templates/sg.yaml
```

**EC2-instanser:**
```bash
aws cloudformation create-stack \
  --stack-name swarm-ec2 \
  --template-body file://templates/ec2.yaml
```

### 1.2 Verifiera att resurserna skapats

```bash
# Kolla status för Security Group
aws cloudformation describe-stacks --stack-name swarm-sg --query 'Stacks[0].StackStatus'

# Kolla status för EC2-instanser
aws cloudformation describe-stacks --stack-name swarm-ec2 --query 'Stacks[0].StackStatus'
```

---

## 2. Initiera Docker Swarm via SSH

Se till att Docker är igång på alla instanser.

### 2.1 Hämta IP-adresser

I terminalen, kör:
```bash
aws cloudformation describe-stacks --stack-name swarm-ec2 --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' --output table
```

Detta genererar en lista på alla privata samt publika IP-adresser för dina EC2-instanser, samt sökvägen för din .pem keyfile. Spara ner dem i t.ex. Notepad++.

### 2.2 Anslut till Manager Node

I terminalen, kör:
```bash
ssh -i Keyswarm1029.pem ec2-user@54.154.62.190
```

**Resultat:**

![SSH anslutning till Manager](https://i.imgur.com/JbMyfV5.png)

### 2.3 Initiera Swarm på Manager

Använd den privata IP-adressen för Manager:

```bash
sudo docker swarm init --advertise-addr 172.31.1.34
```

Du kommer att få en lång token om allt går vägen. **Kopiera denna token!**

![Swarm initierad](https://i.imgur.com/Tg1Uipv.png)

### 2.4 Lägg till Worker 1 och Worker 2

**Worker 1:**

Öppna en ny terminal och kör:
```bash
ssh -i Keyswarm1029.pem ec2-user@34.245.181.76
```

Klistra in join-kommandot med token:
```bash
sudo docker swarm join --token SWMTKN-1-303kpn7av16ntcn1r23e7s6nd9b4m99r5cbk08cpjxz60r16jq-6fjqnyfux22mdtjlzd7pnxft5 172.31.1.34:2377
```

**Resultat:**

![Worker 1 ansluten](https://i.imgur.com/yGOhC3U.png)

*"This node joined a swarm as worker"*

**Worker 2:**

Upprepa samma steg för Worker 2 med dess publika IP-adress.

### 2.5 Verifiera klustret

Gå tillbaka till terminalen för Manager och verifiera att alla noder är anslutna:

```bash
sudo docker node ls
```

![Swarm-kluster verifierat](https://i.imgur.com/o1GJwid.png)

---

## 3. Deploya Docker Stack

### 3.1 Skapa deployment-skript

Här har jag valt att automatisera deployment av Docker Stack genom ett bash-skript istället för att köra kommandona manuellt enligt tutorialen.

Jag började med att försöka sätta ihop ett eget skript baserat på tutorialen, men insåg efter ett tag att det inte blev rätt, så bad LLM att hjälpa mig fixa till det.

**Skriptet gör följande:**
1. Skapar docker-stack.yml automatiskt (definierar services som nginx och visualizer)
2. Deployer stacken till Docker Swarm
3. Verifierar deployment genom att visa status för alla services

**Komplett skript:** `templates/docker-stack.sh`

### 3.2 Kör deployment-skriptet

På Manager-noden körde jag:
```bash
# Gör skriptet körbart
chmod +x deploy-swarm.sh

# Kör automatisk deployment
./deploy-swarm.sh
```

Skriptet skapade docker-stack.yml, deployade den, och visade automatiskt status för alla services.

### 3.3 Resultat

Stacken "myapp" deployades framgångsrikt med:
- 3 replicas av nginx (web service)
- 1 replica av visualizer (på manager-noden)

---

## 4. Testa och skala

### 4.1 Test Web Access

**Nginx (vilken IP som helst):**

Öppna i webbläsaren:
```
http://54.154.62.190/
```

![Nginx välkomstsida](https://i.imgur.com/YUW0S4b.png)

**Visualizer (Manager public-ip):**

Öppna i webbläsaren:
```
http://54.154.62.190:8080/
```

![Docker Swarm Visualizer](https://i.imgur.com/w2OdD0M.png)

### 4.2 Skala services

**Skala ner till 3 replicas:**
```bash
sudo docker service scale myapp_web=3
```

![Skalning nedåt](https://i.imgur.com/xzAdBXx.png)

**Skala upp till 5 replicas:**
```bash
sudo docker service scale myapp_web=5
```

![Skalning uppåt](https://i.imgur.com/xzAdBXx.png)

---

## 5. Skapa en .NET MVC-app

### 5.1 Skapa ett nytt MVC-projekt

I terminalen:
```bash
mkdir -p app
cd app
dotnet new mvc -n DsDemoWeb -o DsDemoWeb
cd DsDemoWeb
dotnet new gitignore
```

![MVC-projekt skapat](https://i.imgur.com/vZzkIbJ.png)

**Kommentera bort HTTPS-redirection:**

Öppna `Program.cs` och kommentera bort:
```csharp
// app.UseHttpsRedirection();
```

### 5.2 Skapa en Dockerfile

I din app-mapp (DsDemoWeb), skapa en ny fil som heter `Dockerfile` (ingen filändelse), lägg in nedan innehåll och spara:

```dockerfile
# Build & publish
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS production
WORKDIR /app
EXPOSE 80
ENV ASPNETCORE_URLS=http://+:80
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "DsDemoWeb.dll"]
```

### 5.3 Skapa ett ECR repository

I terminalen, kör:
```bash
AWS_REGION=eu-west-1
REPO=ds-demo-web

# Skapa repository
aws ecr describe-repositories --repository-names "$REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "$REPO" --region "$AWS_REGION"

# Hämta repository URI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_URI=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO}
echo "Repo URI: $REPO_URI"
```

### 5.4 Logga in till ECR

I terminalen, kör:
```bash
AWS_REGION=eu-west-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
```

![ECR login lyckades](https://i.imgur.com/OG7XWim.png)

---

## 6. Bygg och deploya MVC-appen

### 6.1 Multi-arkitektur build

Enligt instruktionen skulle imagen byggas för både amd64 och arm64 arkitekturer. Dock stötte jag på ett känt problem med .NET 9 och QEMU-emulering för arm64 som resulterade i exit code 134 (InvalidCastException).

**Lösning:** Eftersom mina EC2-instanser (t3.micro) använder amd64-arkitektur, byggde jag endast för linux/amd64:

```bash
AWS_REGION=eu-west-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_URI=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ds-demo-web
IMAGE_TAG=v1

# Bygg och pusha image
docker buildx build \
  --platform linux/amd64 \
  -t ${REPO_URI}:${IMAGE_TAG} \
  -f Dockerfile \
  --push \
  .
```

Detta är tillräckligt för projektet då alla noder i Swarm-klustret kör på amd64-processorer.

![Docker image pushad till ECR](https://i.imgur.com/BxqAOqe.png)

**Verifiera i AWS Console:**

Gå till ECR → Repositories → ds-demo-web

![ECR repository med v1 tag](https://i.imgur.com/XC9p1OK.png)

### 6.2 Uppdatera deployment-skript

**Uppdatering från test-app till MVC-app:**

Efter att ha byggt och pushat min .NET MVC-applikation till ECR, uppdaterade jag deployment-skriptet på Manager-noden.

SSH:a in på Manager:
```bash
ssh -i Keyswarm1029.pem ec2-user@54.154.62.190
```

Redigera skriptet:
```bash
nano deploy-swarm.sh
```

**Byt ut:**
```bash
image: nginx:stable-alpine
```

**Till:**
```bash
image: 542478884453.dkr.ecr.eu-west-1.amazonaws.com/ds-demo-web:v1
```

Spara: Ctrl+X, Y, Enter

**Gör även ändringen i din lokala .sh-fil** (`templates/docker-stack.sh`) för dokumentation.

### 6.3 IAM Role för ECR-access

**Problem:** EC2-instanserna hade inte behörighet att hämta images från ECR, när jag skulle deploya. 

**Lösning:**

1. **Skapa IAM Role** (om du inte redan har en):///OBS SKA GÖRAS OM FÖR JAG UPPDATERADE EC2.YAML 
   - IAM → Roles → Create role
   - Trusted entity: AWS service → EC2
   - Policy: `AmazonEC2ContainerRegistryReadOnly`
   - Role name: `EC2-ECR-Access`
   - Create role

2. **Tilldela rollen till EC2-instanserna:**
   - EC2 → Instances → Markera alla 3 instanser
   - **OBS:** Instanserna måste stoppas först
   - Instance state → Stop instance (vänta tills stopped)
   - Actions → Security → Modify IAM role
   - Välj: `EC2-ECR-Access`
   - Update IAM role
   - Instance state → Start instance

### 6.4 Deploya MVC-appen

På Manager-noden, kör:
```bash
./deploy-swarm.sh
```

**Detta gör:**
- Skapar docker-stack.yml med MVC-appen
- Deployer till Swarm
- Visar status för alla services

**Verifiera deployment:**
```bash
sudo docker service ps myapp_web
```

**Öppna i webbläsaren:**
```
http://54.154.62.190/
```

Din MVC-app körs nu på Swarm med 3 replicas! 🎉

---

## Bilaga: Att använda IaC Generator (*1)

Som jag nämnde tidigare har jag använt mig av CloudFormation för att skapa vissa av resurserna. Nedan följer ett exempel på hur man använder IaC generator. Principen är densamma från det att resursen man vill använda till templaten är klar.

### Börja med att skapa en Security Group manuellt

#### 1. Skapa Security Group

Namnge SG samt ange beskrivning.

**Inbound rules:**

- **VPC:** Default
- **SSH:** Port 22 (rekommenderas att använda Your IP address)
- **HTTP:** Port 80, Source: 0.0.0.0/0
- **Custom TCP (Visualizer):** Port 8080, Source: 0.0.0.0/0

![Inbound rules](https://i.imgur.com/bi27vCg.png)

**Outbound rules:**

- All traffic
- Destination: 0.0.0.0/0

Lägg till tags om så önskas.

**Create security group**

![Security Group skapad](https://i.imgur.com/cJhQukX.png)

Då ska det se ut så här:

![Security Group översikt](https://i.imgur.com/0o40PxR.png)

#### 2. Self-reference för Swarm-kommunikation

Gå in på **Edit inbound rules**, för nu ska vi referera SG till sig själv.

Lägg till följande regler som alla refererar till samma Security Group:
- **Swarm Management:** Port 2377 (TCP)
- **Swarm Communication:** Port 7946 (TCP & UDP)
- **Overlay Network:** Port 4789 (UDP)

![Self-reference rules](https://i.imgur.com/GX7oGeQ.png)

**Spara**

Skriv gärna ner Resource identifier, det behövs till IaC Generator.

### IaC Generator

Nu ska vi skapa själva templaten för CloudFormation.

#### 1. Navigera till CloudFormation → IaC generator

![IaC Generator](https://i.imgur.com/Cx2TBf8.png)

#### 2. Starta scan

Starta en new scan och välj **Scan specific resource**

![Scan specific resource](https://i.imgur.com/LDXsTcD.png)

#### 3. Välj Security Group

Sök efter SG, bocka i din Security Group och **Start scan**

![Start scan](https://i.imgur.com/zvp2M2x.png)

#### 4. Skapa template

När scan är klar, klicka **Create template**

![Create template](https://i.imgur.com/rZDKYDn.png)

#### 5. Namnge template

Namnge templaten och välj **Next**

![Namnge template](https://i.imgur.com/7nH0pFj.png)

#### 6. Välj rätt resource

Nu får du upp alla SG du har skapat. Se till att välja rätt Resource identifier.

![Välj resource](https://i.imgur.com/ldG4CtS.png)

Tryck **Next** på kommande två fönster.

#### 7. Skapa template

**Create Template**

![Template skapad](https://i.imgur.com/D12hKdO.png)

Nu har templaten skapats med ett långt skript.

**Tips:** Parametrisera skriptet. Det kan vara knepigt i början, så då kan man be LLM om hjälp.

Välj att spara ner skriptet, så kan du använda det flera gånger som det är eller med ändringar.

![Spara template](https://i.imgur.com/bi27vCg.png)

**OBS!** Se till att radera stacken under CloudFormation samt SG innan du kör skriptet, eller uppdatera templaten med andra namn.