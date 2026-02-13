# BarberAPP


## Para la carpeta barberapp-backend abre una terminal y sigue los pasos

### Pasos a seguir:

1. cd barberapp-backend

2. npm init -y

3. npm install express mongoose bcryptjs cors dotenv multer

4. npm install -D nodemon

### Fuera de terminal

5. Crear un archivo con nombre: **.env**

Dentro de este pondras:

PORT=3000

# Usuario 1
USER1_MONGO_URI=mongodb+srv://jcruzofcc_db_user:CONTRASEÑA@cluster0.mongodb.net/BarberApp?retryWrites=true&w=majority
USER1_NAME=jcruzofcc_db_user

# Usuario 2
USER2_MONGO_URI=mongodb+srv://za230110385_db_user:CONTRASEÑA@cluster0.mongodb.net/BarberApp?retryWrites=true&w=majority
USER2_NAME=za230110385_db_user

# Usuario activo (1 o 2)
ACTIVE_USER=1

Este archivo se tiene que crear ya que cuando realizamos un push a Github este nunca se sube ya que lleve credenciales privadas para la conexión a la base de datos.

Te recomiendo copiar el codigo de ese archivo con las credenciales correctas en un txt para que solo copies y pegues cuando lo creas de nuevo

---

***Se crea dentro de la carpeta barberapp-backend***

---
