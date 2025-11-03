
# Skalbara molnapplikationer. Inlämning 2 del 1 - Docker Swarm .NET MVC application 





# Docker Swarm - Containerorkestrering

Ett projekt som demonstrerar container-orkestrering med Docker Swarm för att köra en skalbar webbapplikation.

## Om Projektet

Detta är ett skolprojekt för att lära sig om container-orkestrering och hur man bygger skalbara applikationer med Docker Swarm.

**Syfte:** Visa hur man:
- Skapar en Docker Swarm-cluster
- Deplojar multi-container applikationer
- Skalar tjänster dynamiskt
- Hanterar load balancing
- Implementerar redundans och failover

## Teknisk Stack

- **Orkestrering:** Docker Swarm
- **Container Runtime:** Docker
- **Applikation:** [Beskriv din app]
- **Load Balancing:** Swarm built-in
- **Networking:** Overlay network

## Arkitektur

```
Manager Node(s) → Worker Node(s) → Containers
```

## Dokumentation

Se **Rapport.md** för fullständig teknisk dokumentation om arkitektur, implementation och slutsatser.

Detaljerade setup-instruktioner finns i mappen `Instruktioner/`.

## Projektstruktur

```
├── docker-compose.yml  # Swarm stack definition
├── Dockerfiles/        # Container definitions
├── Instruktioner/      # Setup guides
└── Rapport.md         # Teknisk rapport
```

## Student

Maria Schillström  
Kurs: Skalbar värdmiljö  
November 2025