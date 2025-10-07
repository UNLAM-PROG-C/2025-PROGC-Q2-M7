"""
Cliente de chat por consola (Python)
Conecta a 127.0.0.1:5000 y mantiene un chat por turnos con el servidor.
- Pide el nombre al inicio.
- Límite de 280 caracteres por mensaje (se descarta el resto).
- La palabra clave 'chau' finaliza el chat y cierra la conexión.

Uso: python client.py
"""

import socket

HOST = '127.0.0.1'
PORT = 5000
MAX_LEN = 280


def recv_line(sock):
    buffer = b''
    while True:
        chunk = sock.recv(1)
        if not chunk:
            return None
        if chunk == b'\n':
            break
        buffer += chunk
        if len(buffer) > 4096:
            break
    try:
        return buffer.decode('utf-8', errors='replace')
    except Exception:
        return buffer.decode('utf-8', errors='ignore')


def send_line(sock, text):
    if not text.endswith('\n'):
        text = text + '\n'
    sock.sendall(text.encode('utf-8'))


def main():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((HOST, PORT))
        print(f'Conectado a {HOST}:{PORT}')

        # Esperar el prompt del servidor para pedir nombre
        prompt = recv_line(s)
        if prompt is None:
            print('Servidor cerró la conexión')
            return
        print(prompt.strip())
        name = input('Tu nombre: ').strip()
        if len(name) == 0:
            name = 'Anon'
        send_line(s, name)

        try:
            while True:
                # Turno del servidor (esperar mensaje)
                server_msg = recv_line(s)
                if server_msg is None:
                    print('Servidor se desconectó')
                    break
                server_msg = server_msg.strip()
                print(server_msg)
                if server_msg.endswith('chau') or server_msg == 'SERVER: chau':
                    print('Servidor finalizó el chat')
                    break

                # Turno del cliente (enviar mensaje)
                texto = input(f'{name}: ')[:MAX_LEN]
                send_line(s, texto)
                if texto == 'chau':
                    print('Has pedido finalizar (chau)')
                    break

        finally:
            s.close()
            print('Conexión cerrada')


if __name__ == '__main__':
    main()
