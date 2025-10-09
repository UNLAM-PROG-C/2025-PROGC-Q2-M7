# ServidorChat.py
import socket
import threading
import sys

# --- Configuración ---
HOST = '127.0.0.1'  # IP de loopback local
PORT = 5000         # Puerto a utilizar
BUFFER_SIZE = 1024  # Tamaño del búfer de recepción
MAX_MSG_LEN = 280   # Límite de caracteres por mensaje
FORMATO = 'utf-8'   # Codificación de mensajes

# Lista de clientes conectados (socket, nombre_usuario)
clientes_conectados = []
# Lock para manejar el acceso concurrente a la lista de clientes
clientes_lock = threading.Lock()

def manejar_cliente(conexion, direccion):
    """
    Función que maneja la comunicación con un cliente individual.
    Corre en su propio hilo.
    """
    print(f"[NUEVA CONEXIÓN] {direccion} conectado.")
    nombre_usuario = ""
    conectado = True
    
    try:
        # 1. Recibir el nombre de usuario
        nombre_usuario_raw = conexion.recv(BUFFER_SIZE).decode(FORMATO)
        nombre_usuario = nombre_usuario_raw[:MAX_MSG_LEN]
        
        # 2. Agregar el cliente a la lista global
        with clientes_lock:
            clientes_conectados.append((conexion, nombre_usuario))
            
        # Notificar a todos los demás que un nuevo usuario se ha unido
        mensaje_bienvenida = f"📢 {nombre_usuario} se ha unido al chat."
        print(mensaje_bienvenida)
        broadcast(mensaje_bienvenida, conexion)

        # Bucle principal de recepción de mensajes del cliente
        while conectado:
            try:
                mensaje = conexion.recv(BUFFER_SIZE).decode(FORMATO)
                
                if not mensaje: # Cliente desconectado abruptamente
                    break

                # Aplicar límite de 280 caracteres y procesar el mensaje
                mensaje_procesado = mensaje[:MAX_MSG_LEN].strip()
                
                if mensaje_procesado.lower() == 'chau':
                    conectado = False # El cliente pidió salir
                else:
                    # Formatear y retransmitir el mensaje
                    mensaje_a_enviar = f"[{nombre_usuario}]: {mensaje_procesado}"
                    print(f"RECIBIDO: {mensaje_a_enviar}")
                    broadcast(mensaje_a_enviar, conexion)

            except ConnectionResetError:
                # Se perdió la conexión
                conectado = False
            except Exception as e:
                print(f"[ERROR] En el manejo del cliente {nombre_usuario}: {e}")
                conectado = False

    finally:
        # Cerrar y limpiar la conexión
        print(f"[DESCONEXIÓN] {nombre_usuario} ha dejado el chat.")
        
        with clientes_lock:
            if (conexion, nombre_usuario) in clientes_conectados:
                clientes_conectados.remove((conexion, nombre_usuario))
        
        conexion.close()
        
        # Notificar a los demás de la salida
        mensaje_salida = f"💔 {nombre_usuario} ha abandonado el chat."
        print(mensaje_salida)
        broadcast(mensaje_salida, None) # Enviar a todos, incluso si el socket es el mismo (ya se cerró)

def broadcast(mensaje, remitente_conexion=None):
    """
    Envía un mensaje a todos los clientes conectados, excepto al remitente si se especifica.
    """
    # Convertir el mensaje a bytes y añadir un salto de línea para mejor visualización en consola
    bytes_a_enviar = (mensaje + '\n').encode(FORMATO)
    
    with clientes_lock:
        # Iterar sobre una copia de la lista por seguridad
        clientes_a_remover = []
        for conn, nombre in list(clientes_conectados):
            if conn != remitente_conexion:
                try:
                    conn.sendall(bytes_a_enviar)
                except:
                    # Si falla el envío, marcamos al cliente para removerlo
                    clientes_a_remover.append((conn, nombre))
        
        # Remover clientes fallidos (manejo de desconexión abrupta)
        for conn, nombre in clientes_a_remover:
            if (conn, nombre) in clientes_conectados:
                 clientes_conectados.remove((conn, nombre))
                 print(f"[REMOVIDO] Cliente fallido: {nombre}")


def entrada_servidor():
    """
    Función que maneja la entrada de comandos del servidor (p.ej., 'chau').
    Corre en su propio hilo.
    """
    while True:
        try:
            comando = sys.stdin.readline().strip()
            if comando.lower() == 'chau':
                print("[SERVIDOR] Iniciando cierre ordenado...")
                
                # Enviar mensaje de cierre a todos los clientes
                mensaje_cierre = "🚨 El servidor se está cerrando. ¡Adiós!"
                broadcast(mensaje_cierre, None)
                
                # Cerrar ordenadamente todas las conexiones
                with clientes_lock:
                    for conn, _ in clientes_conectados:
                        conn.close()
                    clientes_conectados.clear()
                
                # Cierra el socket principal del servidor
                servidor.close()
                print("[SERVIDOR] Servidor cerrado. Finalizando el programa.")
                
                # Fuerza la salida de todos los hilos
                import os
                os._exit(0) 
            else:
                 print("Comando no reconocido. Use 'chau' para salir.")
        except EOFError:
            # Esto puede ocurrir si se cierra la entrada estándar
            break
        except Exception as e:
            print(f"[ERROR] En la entrada del servidor: {e}")
            break


def iniciar_servidor():
    """
    Inicializa el socket del servidor y comienza a escuchar conexiones.
    """
    global servidor
    servidor = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    # Permite reusar la dirección (útil para pruebas rápidas)
    servidor.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) 
    
    try:
        servidor.bind((HOST, PORT))
        servidor.listen()
        print(f"[INICIO] Servidor escuchando en {HOST}:{PORT}")
    except Exception as e:
        print(f"[FALLO] No se pudo iniciar el servidor: {e}")
        sys.exit()
    
    # Iniciar hilo para manejar la entrada del servidor ('chau')
    thread_entrada = threading.Thread(target=entrada_servidor)
    thread_entrada.daemon = True # Permite que el programa termine si el hilo principal lo hace
    thread_entrada.start()
    
    # Bucle principal de aceptación de conexiones
    while True:
        try:
            conexion, direccion = servidor.accept()
            # Crear un hilo para cada nuevo cliente
            thread_cliente = threading.Thread(target=manejar_cliente, args=(conexion, direccion))
            thread_cliente.daemon = True # Hace que el hilo muera con el programa principal
            thread_cliente.start()
        except OSError as e:
            # Esto puede ocurrir si el socket del servidor se cierra (al ingresar 'chau')
            if 'Bad file descriptor' in str(e) or 'Invalid argument' in str(e):
                break
            print(f"[ERROR DE ACEPTACIÓN] {e}")
        except Exception as e:
            print(f"[ERROR FATAL] {e}")
            break

if __name__ == "__main__":
    iniciar_servidor()