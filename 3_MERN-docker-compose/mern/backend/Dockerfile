FROM node:18.9.1

WORKDIR /back-dir

COPY package.json .

RUN npm install

EXPOSE 5050 

COPY . . 

CMD [ "npm", "start" ]

