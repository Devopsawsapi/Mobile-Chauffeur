# Étape 1 : Builder Flutter Web
FROM cirrusci/flutter:stable-web AS build

WORKDIR /app

# Copier tout le projet
COPY . .

# Installer les dépendances et builder
RUN flutter pub get
RUN flutter build web --release

# Étape 2 : Servir avec Nginx
FROM nginx:alpine

# Copier le build web de Flutter dans le dossier Nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Exposer le port HTTP
EXPOSE 80

# Lancer Nginx
CMD ["nginx", "-g", "daemon off;"]