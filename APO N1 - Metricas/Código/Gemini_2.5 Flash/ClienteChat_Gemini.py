# ClienteChat.py
import socket
import threading
import sys
import time

# --- Configuración ---
HOST = '127.0.0.1'  # IP del servidor
PORT = 5000         # Puerto del servidor
BUFFER_SIZE = 1024  # Tamaño del búfer de recepción
MAX_MSG_LEN = 280   # Límite de caracteres por mensaje
FORMATO = 'utf-8'   # Codificación de mensajes

cliente = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
conectado = False

def recibir_mensajes():
    """
    Función que escucha continuamente los mensajes del servidor.
    Corre en su propio hilo.
    """
    global conectado
    while conectado:
        try:
            # Recibe hasta que se completa el búfer
            mensaje = cliente.recv(BUFFER_SIZE).decode(FORMATO)
            if not mensaje:
                # El servidor cerró la conexión
                print("\n[DESCONEXIÓN] El servidor cerró la conexión.")
                break
            
            # Imprime el mensaje recibido. '\r' asegura que no interfiera con la entrada del usuario.
            sys.stdout.write('\r' + ' ' * 80 + '\r') # Limpia la línea actual (donde el usuario podría estar escribiendo)
            print(mensaje.strip())
            sys.stdout.flush()
            
        except ConnectionResetError:
            # Servidor cerró abruptamente
            print("\n[ERROR] Conexión perdida con el servidor.")
            break
        except OSError:
            # El socket se cerró localmente (p.ej., por la función enviar_mensajes)
            break
        except Exception as e:
            print(f"\n[ERROR EN RECEPCIÓN] {e}")
            break

    # Limpieza al salir del bucle
    if conectado:
        conectado = False
        try:
            cliente.close()
        except:
            pass
        # Finalizar el programa si la conexión se pierde
        import os
        os._exit(0)


def enviar_mensajes(nombre_usuario):
    """
    Función que lee la entrada del usuario y la envía al servidor.
    Corre en el hilo principal.
    """
    global conectado
    while conectado:
        try:
            # Lee la entrada del usuario (bloqueante)
            mensaje = sys.stdin.readline().strip() 
            
            # Aplicar restricción de 280 caracteres
            mensaje_a_enviar = mensaje[:MAX_MSG_LEN]
            
            if not mensaje_a_enviar:
                # Si el mensaje está vacío, continúa sin enviar
                continue
                
            cliente.send(mensaje_a_enviar.encode(FORMATO))
            
            if mensaje_a_enviar.lower() == 'chau':
                print("[DESCONEXIÓN] Solicitaste salir. Cerrando conexión...")
                conectado = False
                break
                
        except EOFError:
            # Usuario cerró la entrada (Ctrl+D)
            break
        except Exception as e:
            if conectado:
                print(f"\n[ERROR EN ENVÍO] {e}")
            break

    # Limpieza al salir del bucle
    if conectado:
        conectado = False
    try:
        cliente.close()
    except:
        pass
    print("Programa Cliente finalizado.")


def iniciar_cliente():
    """
    Establece la conexión y lanza los hilos de envío y recepción.
    """
    global conectado
    
    # 1. Solicitar nombre de usuario
    nombre_usuario = input("Ingresa tu nombre de usuario: ").strip()
    if not nombre_usuario:
        nombre_usuario = "Anonimo"
        
    print(f"Intentando conectar como '{nombre_usuario}' a {HOST}:{PORT}...")

    # 2. Conectar al servidor
    try:
        cliente.connect((HOST, PORT))
        conectado = True
        print("✅ Conexión establecida. Escribe tu mensaje y presiona Enter. Escribe 'chau' para salir.")
    except ConnectionRefusedError:
        print("❌ Error: No se pudo conectar al servidor. Asegúrate de que el ServidorChat.py esté corriendo.")
        return
    except Exception as e:
        print(f"❌ Error al conectar: {e}")
        return

    # 3. Enviar nombre de usuario al servidor
    cliente.send(nombre_usuario.encode(FORMATO))
    
    # 4. Iniciar hilo de recepción (para recibir mensajes en paralelo)
    hilo_recepcion = threading.Thread(target=recibir_mensajes)
    hilo_recepcion.daemon = True # Para que muera si el hilo principal termina
    hilo_recepcion.start()
    
    # 5. Ejecutar el envío de mensajes en el hilo principal
    enviar_mensajes(nombre_usuario)

if __name__ == "__main__":
    iniciar_cliente()