# Étape 1 : Builder Flutter Web
FROM cirrusci/flutter:stable AS build

WORKDIR /app
COPY . .

# Installer les dépendances et builder le web
RUN flutter pub get
RUN flutter build web --release

# Étape 2 : Servir avec Nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]