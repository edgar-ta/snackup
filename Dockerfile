# ==========================================
# ETAPA 1: Construcción (Builder)
# Usamos una imagen que ya tiene Flutter instalado
# ==========================================
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

# Creamos la carpeta donde vivirá nuestro código en el contenedor
WORKDIR /app

# Copiamos todos los archivos del proyecto al contenedor
COPY . .

# Descargamos las dependencias de Flutter
RUN flutter pub get

# Compilamos la aplicación web en modo producción (Release)
RUN flutter build web --release

# ==========================================
# ETAPA 2: Servidor Web (Nginx)
# Usamos un servidor ultra ligero para servir la app
# ==========================================
FROM nginx:alpine

# Borramos la página por defecto de Nginx
RUN rm -rf /usr/share/nginx/html/*

# Copiamos SOLO la carpeta web ya compilada de la Etapa 1 al servidor
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Exponemos el puerto 80 para que podamos entrar desde el navegador
EXPOSE 80

# Arrancamos el servidor Nginx
CMD ["nginx", "-g", "daemon off;"]