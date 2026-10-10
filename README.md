*This project has been created as part of the 42 curriculum by mignavar, dlopez-l, asaiz-lo, mcaro-ro and cde-migu. *

# Description
Inspired by our own culture and traditions, we decided to make this final project of the 42 curriculum based in a game we love to play, specially in the sumer: Chinchon.

As is often the case with orally transmitted tradition, the rules for this game are different depending on who you ask. For this project we had to argue and then agree to the final rules.

**Chinchón** is a card game for 2 to 4 players using a Spanish deck of 40 or 80 cards (depending on the number of players), where the goal is to form combinations to have the lowest possible score and be the last player to exceed the limit of ////ask//// points.

Each player is dealt 7 cards. On each turn, a players must draw a card from either the stock or the discard pile, and then discard another, trying to group their cards.

Valid combinations must have at least three cards:
- **runs**: consecutive cards of the same suit.
- **trios**: three or more cards of the same number.

To **close** the round, a player must have all their cards laid down, or lay down 6 cards with the seventh being a 3, 2, 1, or Ace. Closing with all cards laid down subtracts 10 points; closing with a single remaining card worth 5 or less adds those points. //// ask/// 

# Instructions

/// ask /// 
To play **Chinchon** you first need to deply the required files on a Linux operating system with an x86_64 architecture using Docker and Docker Compose. Before getting started, make sure your Docker installation is up to date. To do so, you can simply run the following commands in your terminal:
```
sudo apt update
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt install docker-compose-plugin
``` 

Once Docker and Docker Compose are installed, clone the repository and run the Makefile, which will take care of both the build process and the deployment.

``` 
git clone https://github.com/mignavarl/chinchon_transcendence.git 

cd chinchon_transcendence

make

```

//// ask/// --como nos conectamos??

The Makefile executes the following targets in order:

make export: launches a standalone Docker container (not managed by Docker Compose) to build and export the Godot project using Godot 4.7. The generated files are placed in client/web and server/build.
make build: detects your local network IP address, generates the required certificates for a secure HTTPS connection, and runs docker compose build to create the client and server images.
make up: runs docker compose up to start all the services.
Once everything is running, you will see an output similar to the following:

[...]
Catjitsu is configured for:
https://<local_network_ip_address>:8443
Host IP: <local_network_ip_address>
[...]
Open https://<local_network_ip_address>:8443 in the web browser of any device connected to your local network (yes, even a smartphone!) and have fun!


# Team Information

This is a group project created by students from 42 Madrid. Meet the Chinchon Lovers!!

- mignavar - Product Owner, Developer
	Responsible for product planning, frontend and backend development, deployment architecture and the game's graphics and artwork.

- dlopez-l - Developer

- mcaro-ro - Developer
- asaiz-lo - Developer
- cde-migu - Developer

# Project Management

During our first team meetings, we decided to divide the project into two main areas:

Frontend (Game Experience and Multiplayer): responsible for developing the game in Godot and delivering a smooth multiplayer experience.
Backend (User Database, Authentication, and Security): responsible for building a robust backend, managing user data, and implementing user registration and authentication through OAuth.
Once the team was divided into these two areas, we started organizing our work using GitHub Issues to track tasks and development milestones. We adopted a Git Flow workflow, creating a dedicated branch for every new feature before merging it into the main project.

Throughout the development process, we maintained continuous communication using mainly Whatsapp, while holding regular online meetings in person to discuss progress, resolve blockers, and coordinate the integration of each component.

# Technical Stack
/// ask ///

# Database Schema

# Features List

# Modules

## Web

### Major
- **Use a framework for both the frontend and backend**: Godot Engine is used as the frontend framework for the game while ///ask /// is used as the backend framework for the API and server-side functionality.

- **Allow users to interact with other users**. We implement a basic system where you can send and receive messages between users, view user info and add/remove friends from a list. 

- **Implement real-time features using WebSockets or similar technology**: Real-time multiplayer communication using WebSockets through Godot's High-Level Multiplayer API. 
/// ask/// 
- A public API to interact with the database with a secured API key, rate limiting, documentation, and at least 5 endpoints [gtaza-ca, kde-la-c, ldel-val]:The project includes a Django REST API that provides controlled access to persistent application data through multiple endpoints. API access is protected through authentication mechanisms, with rate limiting applied to prevent abuse. The API is documented to make its endpoints and expected requests easier to understand and consume.

### Minor

- **Use an ORM for the database**

- **Custom-made design system with reusable components, including a proper color palette, typography and icons**
- **File upload and management system** /// ask ///

## Accesibility and Internationalization

### Minor
- **Support for multiple languages (at least 3 languages)**. We have translated our project to catalan and euskera, since this is mainly a spanish game.
/// ask ///
- **Support for additional browsers**: Compatibility with Google Chrome, Mozilla Firefox.

## User Management

### Major

- **Standard user management and authentication**. Users can update their information, upload an avatar or choose from our defaults, add friends and see their online status and have access to their personal info page.

### Minor

- **Game statistics and match history**: track iser game statistics, display match history, show achievements and progrssions, with an integrated leaderboard.

## Artificial Intelligence

### Major
- **Introduce AI Opponents for games**. The opponent uses a deterministic decision-making system with controlled variation. Its actions are selected according to the current game state and available cards, giving it consistent behavior while introducing enough randomness to prevent every match from playing out identically.

## Gaming and User Experience

### Major
- **Implement a complete web-based game where users can play against each other**: Complete multiplayer gameplay implemented with Godot's frontend and High-Level Multiplayer API over WebSockets.

- **Remote players - Enable players on separate computers to play the same game in real-time**: Room-based multiplayer system allowing up to four players on different computers to play in real time over the same local network.

- **Multiplayer game (more than two players)**. We support up to 4 players simultaneously with proper synchronization across all clients.

- **Implement advanced 3D graphics using a library like Three.js or Babylon.js**. We created an immersive 3D environment implementing advanced rendering techniques and ensuring smooth performance and user interaction.
----
copiar del canva 
https://canva.link/i4wvg9jypdkdrlg 

# Individual Contributions

# Resources
/// ask ///
copiar de catjitsu xd
