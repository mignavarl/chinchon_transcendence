RED="\033[0;31m"
GREEN="\033[0;32m"
MAGENTA="\033[0;35m"
PINK="\033[0;95m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
NC="\033[0m"

all: 
	docker compose up --build -d
	docker compose start
	@echo ${GREEN}"All services are running ✅" $(NC)

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
	docker compose -f srcs/docker-compose.yml down

re: kill all

.PHONY: all down stop restart create_volumes clean re
