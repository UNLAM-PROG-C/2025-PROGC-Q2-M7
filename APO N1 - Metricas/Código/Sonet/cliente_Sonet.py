"""
Cliente de Chat Concurrente
Se conecta al servidor de chat y permite enviar/recibir mensajes simultáneamente.
Utiliza threading para manejar entrada y salida de forma independiente.
"""

import socket
import threading
import sys
import os

# Configuración del cliente
HOST = '127.0.0.1'
PORT = 5000
MAX_MESSAGE_LENGTH = 280

class ChatClient:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.client_socket = None
        self.username = ""
        self.running = True
        
    def connect(self):
        """Conecta al servidor de chat"""
        try:
            # Crear socket
            self.client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.client_socket.connect((self.host, self.port))
            
            # Solicitar nombre de usuario
            print("=== CHAT CLIENTE ===")
            self.username = input("Ingresa tu nombre de usuario: ").strip()
            
            while not self.username:
                print("El nombre de usuario no puede estar vacío.")
                self.username = input("Ingresa tu nombre de usuario: ").strip()
            
            # Enviar nombre de usuario al servidor
            self.client_socket.send(self.username.encode('utf-8'))
            
            print(f"\nConectado al servidor como '{self.username}'")
            print("Escribe tus mensajes (máximo 280 caracteres)")
            print("Escribe 'chau' para salir\n")
            
            # Iniciar threads para recibir y enviar mensajes
            receive_thread = threading.Thread(target=self.receive_messages, daemon=True)
            send_thread = threading.Thread(target=self.send_messages, daemon=True)
            
            receive_thread.start()
            send_thread.start()
            
            # Esperar a que los threads terminen
            receive_thread.join()
            send_thread.join()
            
        except ConnectionRefusedError:
            print(f"[ERROR] No se pudo conectar al servidor en {self.host}:{self.port}")
            print("[ERROR] Asegúrate de que el servidor esté ejecutándose")
        except Exception as e:
            print(f"[ERROR] Error al conectar: {e}")
        finally:
            self.disconnect()
    
    def receive_messages(self):
        """Recibe mensajes del servidor continuamente"""
        try:
            while self.running:
                try:
                    message = self.client_socket.recv(1024).decode('utf-8')
                    
                    if not message:
                        print("\n[CLIENTE] Conexión cerrada por el servidor")
                        self.running = False
                        break
                    
                    # Limpiar la línea actual y mostrar el mensaje
                    # Esto permite que los mensajes aparezcan incluso mientras el usuario escribe
                    print(f"\r{message}", end='')
                    # Restaurar el prompt
                    print(f"\r> ", end='', flush=True)
                    
                except socket.timeout:
                    continue
                except Exception as e:
                    if self.running:
                        print(f"\n[ERROR] Error recibiendo mensaje: {e}")
                    break
                    
        except Exception as e:
            if self.running:
                print(f"[ERROR] Error en thread de recepción: {e}")
        finally:
            self.running = False
    
    def send_messages(self):
        """Envía mensajes al servidor continuamente"""
        try:
            while self.running:
                try:
                    # Mostrar prompt
                    message = input("> ")
                    
                    if not self.running:
                        break
                    
                    message = message.strip()
                    
                    if not message:
                        continue
                    
                    # Verificar comando de salida
                    if message.lower() == 'chau':
                        self.client_socket.send(message.encode('utf-8'))
                        print("[CLIENTE] Desconectando...")
                        self.running = False
                        break
                    
                    # Limitar longitud del mensaje
                    if len(message) > MAX_MESSAGE_LENGTH:
                        print(f"[ADVERTENCIA] Mensaje truncado a {MAX_MESSAGE_LENGTH} caracteres")
                        message = message[:MAX_MESSAGE_LENGTH]
                    
                    # Enviar mensaje
                    self.client_socket.send(message.encode('utf-8'))
                    
                except EOFError:
                    # Ctrl+Z en Windows o Ctrl+D en Unix
                    break
                except Exception as e:
                    if self.running:
                        print(f"[ERROR] Error enviando mensaje: {e}")
                    break
                    
        except Exception as e:
            if self.running:
                print(f"[ERROR] Error en thread de envío: {e}")
        finally:
            self.running = False
    
    def disconnect(self):
        """Cierra la conexión con el servidor"""
        self.running = False
        
        if self.client_socket:
            try:
                self.client_socket.close()
            except:
                pass
        
        print("\n[CLIENTE] Desconectado del servidor")
        sys.exit(0)


if __name__ == "__main__":
    client = ChatClient(HOST, PORT)
    try:
        client.connect()
    except KeyboardInterrupt:
        print("\n[CLIENTE] Interrupción recibida")
        client.disconnect()
