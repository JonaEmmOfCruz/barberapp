const fs = require('fs');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

console.log('\nBarberApp - Cambiar Usuario de Base de Datos\n');
console.log('Usuarios disponibles:');
console.log('1. jcruzofcc_db_user');
console.log('2. za230110385_db_user\n');

rl.question('Selecciona el usuario (1-2): ', (answer) => {
  let activeUser = '1';
  
  if (answer === '2') {
    activeUser = '2';
  }
  
  // Leer archivo .env
  let envContent = fs.readFileSync('.env', 'utf8');
  
  // Reemplazar ACTIVE_USER
  envContent = envContent.replace(
    /ACTIVE_USER=.*/,
    `ACTIVE_USER=${activeUser}`
  );
  
  fs.writeFileSync('.env', envContent);
  
  const userName = activeUser === '1' ? 'jcruzofcc_db_user' : 'za230110385_db_user';
  
  console.log(`\nUsuario cambiado a: ${userName}`);
  console.log('Ejecuta: npm run dev\n');
  
  rl.close();
});