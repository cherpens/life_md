# life_md

Gestor de Vida GPL nacido del video de LinuxChad titulado El SISTEMA que ha CAMBIADO MI VIDA [life.txt] https://www.youtube.com/watch?v=EUCneUnGjv8&pp=ygUQbGludXhjaGFkIG5vdGlvbg%3D%3D

Dicho gestor necesita de Vim y VimWiki para operar correctamente. Además, el script que se encarga de gestionar todos los archivos, también tiene la opción "--cron" para que, al ser llamado por crontab, no ejecute Vim al haber terminado de hacer todas las comprobaciones y modificaciones que requieran los diferentes archivos según la fecha y las tareas que se hayan completado.

Una opción para usar dicho sistema sería que todos los dispositivos que lo usan tuviesen una carpeta life sincronizada con un servidor central (por ejemplo una RPi que permanece siempre encendida) mediante syncthing.

Entonces, a lo largo del día, se van apuntando en inbox.md (en el movil uso Markor, por ejemplo) todas las ideas o eventos o recordatorios que, más adelante cuando tenga más tiempo, gestionaré a sus respectivos puntos (que si calendar.md, que si ToDo.md, etc...). Cada media noche, por ejemplo, el servidor central se encarga de ejecutar el script de manera automática (poniendo en crontab el comando seguido de la opción --cron) para poner el calendario en el nuevo día, archivar los días pasados, archivar las tareas completadas,etc...

Por otra parte, desde el PC, el usuario que desea gestionar sus archivos debería ejecutar el script ./life.sh, éste se encargará de comprobar la fecha, ponerlo todo en orden y, finalmente, abrirá el archivo index.md con Vim y, teniendo el plugin VimWiki, será fácil navegar por los diferentes campos y organizar los eventos del día...

Y, por ahora, eso es todo.

Gracias LinuxChad, por videos tan inspiradores!
