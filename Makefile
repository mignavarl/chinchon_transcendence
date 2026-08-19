RED="\033[0;31m"
GREEN="\033[0;32m"
MAGENTA="\033[0;35m"
PINK="\033[0;95m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
NC="\033[0m"

all: setup
	docker compose up --build -d
	docker compose start
	@echo ${GREEN}"All services are running ✅" $(NC)
	@$(MAKE) --no-print-directory url

# Los puertos se los preguntamos a compose en vez de escribirlos aqui, asi
# no hay dos sitios que mantener si cambian en docker-compose.yaml.
# "compose port" contesta aunque este todo parado, por eso ademas se mira
# si el contenedor esta vivo antes de decir que la web esta disponible.
url:
	@game=$$(docker compose port frontend 443 2>/dev/null | cut -d: -f2); \
	api=$$(docker compose port backend 8080 2>/dev/null | cut -d: -f2); \
	if [ -z "$$(docker compose ps --status running -q frontend)" ]; then \
		echo $(YELLOW)"Nothing is up yet, launch it with: make ⚠️"$(NC); \
	else \
		echo $(CYAN)"Game: https://localhost:$$game 🎮"$(NC); \
		echo $(CYAN)"API:  http://localhost:$$api/api 🔌"$(NC); \
		echo $(MAGENTA)"El certificado es autofirmado: el navegador avisa, hay que aceptarlo"$(NC); \
	fi

setup:
	@echo $(CYAN)"Generating self-signed SSL certificate... 🔐"$(NC)
	@mkdir -p ./nginx/certs
	@openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout ./nginx/certs/selfsigned.key \
		-out ./nginx/certs/selfsigned.crt \
		-subj "/CN=localhost" 2>/dev/null
	@echo $(GREEN)"Certificate generated in ./nginx/certs ✅"$(NC)

up-%:
	docker compose up $* -d

down:
	docker compose down

stop:
	docker compose stop

build-%:
	docker compose build $* 

restart:
	docker compose restart

logs:
	docker compose logs

# Clean all images and networks
kill: down 
# 	docker volume rm $$(docker volume ls -q)
	docker rmi $$(docker images -aq)


clean:
	@echo $(RED)"Deleting Volumes... 🧹"$(NC)
	docker compose down -v

re: kill all

.PHONY: all setup url down stop restart create_volumes clean re