"""
Servidor de chat por consola (Python)
Escucha en 127.0.0.1:5000 y maneja un chat por turnos con un cliente.
Reglas implementadas:
- Mensajes por turno.
- Límite de 280 caracteres (se descarta el resto).
- La palabra clave 'chau' finaliza el chat y cierra ambos programas.

Uso: python server.py
"""

import socket
import threading

HOST = '127.0.0.1'
PORT = 5000
MAX_LEN = 280


def recv_line(conn):
    """Recibe una línea terminada en '\n'. Devuelve None si la conexión se cierra."""
    buffer = b''
    while True:
        chunk = conn.recv(1)
        if not chunk:
            return None
        if chunk == b'\n':
            break
        buffer += chunk
        if len(buffer) > 4096:  # protección contra líneas enormes
            break
    try:
        return buffer.decode('utf-8', errors='replace')
    except Exception:
        return buffer.decode('utf-8', errors='ignore')


def send_line(conn, text):
    if not text.endswith('\n'):
        text = text + '\n'
    conn.sendall(text.encode('utf-8'))


def handle_chat(conn, addr):
    print(f'Conexión desde {addr}')
    # Primer paso: recibir el nombre del cliente
    send_line(conn, 'SERVER: Bienvenido. Ingresa tu nombre:')
    name = recv_line(conn)
    if name is None:
        print('Conexión cerrada antes de enviar nombre')
        conn.close()
        return
    name = name.strip()
    print(f'Nombre del cliente: {name}')

    print('Comienza el chat. Turnos: servidor -> cliente -> servidor ...')

    try:
        while True:
            # Turno del servidor
            mensaje = input('Tu (servidor): ')[:MAX_LEN]
            if mensaje == 'chau':
                send_line(conn, f'SERVER: {mensaje}')
                print('Cerrando por palabra clave "chau"')
                break
            send_line(conn, f'SERVER: {mensaje}')

            # Turno del cliente
            cliente_msg = recv_line(conn)
            if cliente_msg is None:
                print('Cliente se desconectó')
                break
            cliente_msg = cliente_msg.strip()
            # Truncar a 280 chars
            if len(cliente_msg) > MAX_LEN:
                cliente_msg = cliente_msg[:MAX_LEN]
            print(f'{name}: {cliente_msg}')
            if cliente_msg == 'chau':
                print('Cliente pidió finalizar (chau)')
                break

    except Exception as e:
        print('Error en el chat:', e)
    finally:
        conn.close()
        print('Conexión finalizada')


def main():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, PORT))
        s.listen(1)
        print(f'Servidor escuchando en {HOST}:{PORT}... Esperando cliente...')
        conn, addr = s.accept()
        with conn:
            handle_chat(conn, addr)


if __name__ == '__main__':
    main()
