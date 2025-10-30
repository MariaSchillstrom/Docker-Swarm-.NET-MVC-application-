
# 






# DockerSwarm 

## 1. Skapa resurser 

Jag började med att skapa nedan resurser manuellt, för att sedan skapa en cloud formation template via Iac generator för automatisering. 

- Security group (*1)
- EC2 till swarm-kluster. Skapade 1 manuellt, modifierade skriptet till 3.
  Skripten ligger i sin helhet under Templates.

  Skripten körs sedan i terminal med ....?? 

  Gå in på AWS och se om de skapats eller kör ....??  i terminalen 

  ## 2. Initiera Docker Swarm via SSH

  Se till att Docker är igång.

  
  I terminalen kör ; 

 ```
aws cloudformation describe-stacks --stack-name swarm-ec2 --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' --output table
```

Detta genererar en lista på alla privata samt publika ip adresser för dina EC2, samt sökvägen för din .pem keyfile. Spara ner dem vid sidan av,i tillexempel notepad++.

Skapa 3 st ; ssh -i ~/.ssh/your-key.pem ec2-user@<manager-public-ip> 

Ersätt your-key.pem med din sökväg, samt public ip för manager, worker 1 samt worker 2.


## 2.1 Anslut till Manager Node

I terminalen kör;

```
ssh -i Keyswarm1029.pem ec2-user@54.154.62.190
```
Resultatet ska bli; 


https://i.imgur.com/JbMyfV5.png



## 2.2 Initisera Swarm på Manager

Använd den privata ip- adressen för manager

```
sudo docker swarm init --advertise-addr 172.31.1.34

```
Då kommer du att få en lång token om allt går vägen, kopiera denna 

https://i.imgur.com/Tg1Uipv.png


## 2.3 Lägg till Worker 1 samt Worker 2

Öpnna en ny terminal

***Worker1, public-ip** 

```
ssh -i Keyswarm1029.pem ec2-user@34.245.181.76

```
```
sudo docker swarm join --token SWMTKN-1-303kpn7av16ntcn1r23e7s6nd9b4m99r5cbk08cpjxz60r16jq-6fjqnyfux22mdtjlzd7pnxft5 172.31.1.34:2377

```
Resultatet ska se ut så här

https://i.imgur.com/yGOhC3U.png

***This node joined a swarm as worker*** 


Upprepa samma process för Worker 2.


Gå tillbaka till terminalen för manager och verifiera 

```
sudo docker node ls

```

https://i.imgur.com/o1GJwid.png


## 3. Skapa en Docker Compose fil

## 3.1 Skapa stacken
## 3.1 Skapa deployment-skript

Här har jag valt att automatisera deployment av Docker Stack genom ett bash-skript istället för att köra kommandona manuellt enligt tutorialen.

Jag började med att försöka sätta ihop ett eget skript baserat på tutorialen, men insåg efter ett tag att det inte blev rätt, så bad LLM att hjälpa mig fixa till det.

Skriptet gör följande:
1. Skapar docker-stack.yml automatiskt (definierar services som nginx och visualizer)
2. Deployer stacken till Docker Swarm
3. Verifierar deployment genom att visa status för alla services

**Komplett skript ligger under templates/docker-stack.sh**

## 3.2 Kör deployment-skriptet

På Manager-noden körde jag:
```bash
# Gör skriptet körbart
chmod +x deploy-swarm.sh

# Kör automatisk deployment
./deploy-swarm.sh
```

Skriptet skapade docker-stack.yml, deployade den, och visade automatiskt status för alla services.

## 3.3 Resultat

Stacken "myapp" deployades framgångsrikt med:
- 3 replicas av nginx (web service)
- 1 replica av visualizer (på manager-noden)


## 4. Testa,skala ner samt upp

Öppna någon av dina ip-adresser i Webläsaren; 

http://54.154.62.190/

Då ska du få upp detta 

https://i.imgur.com/YUW0S4b.png


Öppna manager public-ip 

http://54.154.62.190:8080/

Då ska du få upp denna vy

https://i.imgur.com/w2OdD0M.png


***Skala ner*** sudo docker service scale myapp_web=3

https://i.imgur.com/xzAdBXx.png

***Skala upp*** sudo docker service scale myapp_web=5

https://i.imgur.com/xzAdBXx.png


## 5. Skapa en .NET MVC app

## 5.1 Skapa ett nytt MVC i samma folder du är i. 

I terminalen;

```
mkdir -p app
cd app
dotnet new mvc -n DsDemoWeb -o DsDemoWeb
cd DsDemoWeb
dotnet new gitignore
```
https://i.imgur.com/vZzkIbJ.png


Gå in i program, och kommentera bort // app.UseHttpsRedirection();

## 5.2 Skapa en docker file

I din app-mapp, skapa en ny fil som heter Docker,lägg in nedan i filen och spara.

```
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish


FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS production
WORKDIR /app
EXPOSE 80
ENV ASPNETCORE_URLS=http://+:80
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "DsDemoWeb.dll"]
```

## 5.3 Skapa ett ECR repository

I terminalen kör;

```
AWS_REGION=eu-west-1
REPO=ds-demo-web


aws ecr describe-repositories --repository-names "$REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "$REPO" --region "$AWS_REGION"


ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_URI=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO}
echo "Repo URI: $REPO_URI"
```

Logga in

I terminalen kör;

```
AWS_REGION=eu-west-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
```

https://i.imgur.com/OG7XWim.png



## 6. Bygg och pusha en multi-arkitektur image med Buildx

## 6.1 Multi-arkitektur build

Enligt instruktionen skulle imagen byggas för både amd64 och arm64 arkitekturer. Dock stötte jag på ett känt problem med .NET 9 och QEMU-emulering för arm64 som resulterade i exit code 134 (InvalidCastException).

Eftersom mina EC2-instanser (t3.micro) använder amd64-arkitektur, byggde jag endast för linux/amd64:


```
docker buildx build \
  --platform linux/amd64 \
  -t ${REPO_URI}:${IMAGE_TAG} \
  --push \
  .
```

Detta är tillräckligt för projektet då alla noder i Swarm-klustret kör på amd64-processorer.

https://i.imgur.com/BxqAOqe.png

Gå till ECR-Repositories-ds-demo-web

https://i.imgur.com/XC9p1OK.png

## 6.2 

Uppdatera din .yml med image istället för nginx. 

ssh:a in på din manager 

```
scp -i Keyswarm1029.pem templates/docker-stack.sh ec2-user@54.154.62.190:~/deploy-swarm.sh
```
```
nano deploy-swarm.sh
```

Byt ut 

```
image: nginx:stable-alpine
```

till 

```
image: 542478884453.dkr.ecr.eu-west-1.amazonaws.com/ds-demo-web:v1
```
Ctrl+X, Y, Enter

Gör även ändringen i din .sh fil 


## 6.3 Deploya

OBS! Jag kunde inte få det att fungera, för tydligen så hade jag inte IAM access som jag trodde så först fick jag gå till AWS och .......

I terminalen, på din manager kör; 

```
./docker-stack.sh
```
Detta skapar;
**Docker-stack.yml med min MVC-app**
**Deploya till swarm**
**Visa status för alla services**


















(*1)
# Att använda Iac generator. 

Som jag nämnde tidigare så har jag använt mig av Cloud formation för att skapa vissa av resurserna. Nedan följer ett exempel på hur man använder Iac generator. Principen är densamma från dess att resursen man vill "använda" till templaten är klar. 

## Börja med att skapa en Security Group manuellt

### 1. Skapa Security Group i två steg


Namnge SG samt ange beskrivning

#### Inbound rules https://i.imgur.com/bi27vCg.png

#### Inbound rules

- **VPC**: Default
- **SSH**: Port 22 (rekommenderas att använda Your IP address)
- **HTTP**: Port 80, Source: 0.0.0.0/0
- **Custom TCP (Visualizer)**: Port 8080, Source: 0.0.0.0/0

#### Outbound rules

All traffic https://i.imgur.com/bi27vCg.png
Destination: Custom 

* Lägg till tags om så önskas.

Create security group

https://i.imgur.com/cJhQukX.png


Då ska det se ut så här 

https://i.imgur.com/0o40PxR.png


Gå in på Edit inbound rules, för nu ska vi referera SG till sig själv.

Lägg till enligt nedan, och välj din skapade SG. 

Spara

https://i.imgur.com/GX7oGeQ.png

Skriv gärna ner Resource identifier, det behövs till Iac Generator. 


### Iac Generator

Nu ska vi skapa själva templaten för Cloud formation. 

Navigera till CloudFormation - Iac generator. 

https://i.imgur.com/Cx2TBf8.png

Starta en new scan och välj - scan specific resource 

https://i.imgur.com/LDXsTcD.png

Sök efter SG, bocka i och start scan 

https://i.imgur.com/zvp2M2x.png

När scan är klar ska du skapa en template 

Create template 

https://i.imgur.com/rZDKYDn.png


Namnge templaten och välj next 

https://i.imgur.com/7nH0pFj.png


Nu får du upp alla SG du har skapat, se till att välja rätt Resource identifier. 

https://i.imgur.com/ldG4CtS.png


Tryck next på kommande två fönster

Create Template 

https://i.imgur.com/D12hKdO.png


Nu har templaten skapats med ett långt skript.

Tips är att paramatisera skriptet, det kan vara knepigt i början så då kan man be LLM om hjälp.

Välj att spara ner skriptet , så kan du använda det flera gånger som det är eller med ändringar.

https://i.imgur.com/bi27vCg.png

OBS! Se till att radera stacken under CloudFormation samt SG innan du kör skriptet, eller uppdatera templaten med andra namn.





