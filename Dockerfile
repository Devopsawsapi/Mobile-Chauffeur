# Étape 1 : Builder Flutter Web
FROM cirrusci/flutter:stable AS build

WORKDIR /app
COPY . .

RUN flutter build web

# Étape 2 : Servir avec Nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
