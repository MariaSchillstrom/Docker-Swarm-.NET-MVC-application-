
# 






# DockerSwarm 





























# Att använda Iac generator. 

Som jag nämnde tidigare så har jag använt mig av Cloud formation för att skapa vissa av resurserna. Nedan följer ett exempel på hur man använder Iac generator. Principen är densamma från dess att resursen man vill "använda" till templaten är klar. 

## Börja med att skapa en Security Group manuellt. 

### Security Group

## 1. Skapa en securitygroup i två steg 

Steg 1-

Namnge SG samt ange beskrivning

#### Inbound rules 

VPC Default
SSH: Port 22, rekommenderas att använda Your IP address 
HTTP: Port 80, Source 0.0.0.0/0
Custom TCP (Visualizer): Port 8080, Source 0.0.0.0/0

#### Outbound rules

All traffic 
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







