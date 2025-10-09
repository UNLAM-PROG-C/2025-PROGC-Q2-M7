"""
Servidor de Chat Concurrente
Permite múltiples clientes conectados simultáneamente en una sala de chat.
Utiliza threading para manejar cada cliente de forma independiente.
"""

import socket
import threading
import sys

# Configuración del servidor
HOST = '127.0.0.1'
PORT = 5000
MAX_MESSAGE_LENGTH = 280

class ChatServer:
    def __init__(self, host, port):
        self.host = host
        self.port = port
        self.server_socket = None
        self.clients = []  # Lista de tuplas (socket, nombre_usuario, direccion)
        self.clients_lock = threading.Lock()  # Lock para acceso seguro a la lista
        self.running = True
        
    def start(self):
        """Inicia el servidor y comienza a escuchar conexiones"""
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(5)
            self.server_socket.settimeout(1.0)  # Timeout para permitir verificar running
            
            print(f"[SERVIDOR] Servidor iniciado en {self.host}:{self.port}")
            print("[SERVIDOR] Esperando conexiones...")
            print("[SERVIDOR] Escribe 'chau' para cerrar el servidor\n")
            
            # Thread para aceptar conexiones
            accept_thread = threading.Thread(target=self.accept_connections, daemon=True)
            accept_thread.start()
            
            # Thread para comandos del servidor
            command_thread = threading.Thread(target=self.server_commands, daemon=True)
            command_thread.start()
            
            # Mantener el programa activo
            accept_thread.join()
            command_thread.join()
            
        except Exception as e:
            print(f"[ERROR] Error al iniciar el servidor: {e}")
            self.shutdown()
    
    def accept_connections(self):
        """Acepta nuevas conexiones de clientes"""
        while self.running:
            try:
                client_socket, client_address = self.server_socket.accept()
                
                # Recibir el nombre de usuario
                try:
                    username = client_socket.recv(1024).decode('utf-8').strip()
                    if not username:
                        client_socket.close()
                        continue
                    
                    # Agregar cliente a la lista
                    with self.clients_lock:
                        self.clients.append((client_socket, username, client_address))
                    
                    print(f"[SERVIDOR] {username} se ha conectado desde {client_address}")
                    
                    # Notificar a todos los clientes
                    self.broadcast(f"[SERVIDOR] {username} se ha unido al chat", None)
                    
                    # Iniciar thread para manejar este cliente
                    client_thread = threading.Thread(
                        target=self.handle_client,
                        args=(client_socket, username, client_address),
                        daemon=True
                    )
                    client_thread.start()
                    
                except Exception as e:
                    print(f"[ERROR] Error al procesar nuevo cliente: {e}")
                    client_socket.close()
                    
            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    print(f"[ERROR] Error aceptando conexiones: {e}")
                break
    
    def handle_client(self, client_socket, username, address):
        """Maneja la comunicación con un cliente específico"""
        try:
            while self.running:
                try:
                    # Recibir mensaje del cliente
                    message = client_socket.recv(1024).decode('utf-8')
                    
                    if not message:
                        # Cliente desconectado
                        break
                    
                    message = message.strip()
                    
                    # Verificar si el cliente quiere desconectarse
                    if message.lower() == 'chau':
                        print(f"[SERVIDOR] {username} se despidió del chat")
                        self.broadcast(f"[SERVIDOR] {username} ha salido del chat", client_socket)
                        break
                    
                    # Limitar longitud del mensaje
                    if len(message) > MAX_MESSAGE_LENGTH:
                        message = message[:MAX_MESSAGE_LENGTH]
                    
                    # Broadcast del mensaje a todos los demás clientes
                    formatted_message = f"{username}: {message}"
                    print(f"[MENSAJE] {formatted_message}")
                    self.broadcast(formatted_message, client_socket)
                    
                except socket.timeout:
                    continue
                except Exception as e:
                    print(f"[ERROR] Error procesando mensaje de {username}: {e}")
                    break
                    
        finally:
            self.remove_client(client_socket, username)
    
    def broadcast(self, message, sender_socket):
        """Envía un mensaje a todos los clientes excepto al remitente"""
        with self.clients_lock:
            disconnected_clients = []
            
            for client_socket, username, address in self.clients:
                if client_socket != sender_socket:
                    try:
                        client_socket.send((message + '\n').encode('utf-8'))
                    except Exception as e:
                        print(f"[ERROR] No se pudo enviar mensaje a {username}: {e}")
                        disconnected_clients.append(client_socket)
            
            # Remover clientes desconectados
            for client_socket in disconnected_clients:
                self.remove_client(client_socket, None)
    
    def remove_client(self, client_socket, username=None):
        """Remueve un cliente de la lista y cierra su socket"""
        with self.clients_lock:
            for client_info in self.clients[:]:
                if client_info[0] == client_socket:
                    self.clients.remove(client_info)
                    if username is None:
                        username = client_info[1]
                    break
        
        try:
            client_socket.close()
        except:
            pass
        
        if username:
            print(f"[SERVIDOR] {username} se ha desconectado")
    
    def server_commands(self):
        """Maneja comandos del servidor desde la consola"""
        while self.running:
            try:
                command = input()
                if command.strip().lower() == 'chau':
                    print("\n[SERVIDOR] Cerrando servidor...")
                    self.shutdown()
                    break
            except Exception as e:
                if self.running:
                    print(f"[ERROR] Error leyendo comando: {e}")
    
    def shutdown(self):
        """Cierra todas las conexiones y detiene el servidor"""
        self.running = False
        
        # Notificar a todos los clientes
        self.broadcast("[SERVIDOR] El servidor se está cerrando. Adiós!", None)
        
        # Cerrar todas las conexiones de clientes
        with self.clients_lock:
            for client_socket, username, address in self.clients[:]:
                try:
                    client_socket.close()
                except:
                    pass
            self.clients.clear()
        
        # Cerrar socket del servidor
        if self.server_socket:
            try:
                self.server_socket.close()
            except:
                pass
        
        print("[SERVIDOR] Servidor cerrado correctamente")
        sys.exit(0)


if __name__ == "__main__":
    server = ChatServer(HOST, PORT)
    try:
        server.start()
    except KeyboardInterrupt:
        print("\n[SERVIDOR] Interrupción recibida")
        server.shutdown()
