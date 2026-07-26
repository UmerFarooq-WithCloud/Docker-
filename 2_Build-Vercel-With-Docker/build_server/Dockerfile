FROM ubuntu:focal

RUN apt-get update -y
RUN apt-get install curl -y
RUN curl -sL https://deb.nodesource.com/setup_20.x | bash -
RUN apt-get upgrade -y

RUN apt-get install nodejs -y 
RUN apt-get install git -y

WORKDIR /app

COPY bash.sh bash.sh
COPY script.js script.js 
COPY package*.json .

RUN npm install 

RUN chmod +x bash.sh
RUN chmod +x script.js 

ENTRYPOINT [ "/app/bash.sh" ]

