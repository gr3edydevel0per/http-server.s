.intel_syntax noprefix

.section .data
response:
    .ascii "HTTP/1.0 200 OK\r\n"
    .ascii "Content-Type: text/plain\r\n"
    .ascii "Content-Length: 13\r\n"
    .ascii "\r\n"
    .ascii "Hello World!\n"
response_end:

.equ RESP_LEN, response_end - response


.section .bss
.lcomm sockaddr_in, 16
.comm recv_buffer, 1024


.section .text
.global _start

_start:

    # --- Create a TCP socket ---
    mov rax, 41              # socket syscall
    mov rdi, 2               # AF_INET (IPv4)
    mov rsi, 1               # SOCK_STREAM (TCP)
    mov rdx, 0               # Use the default TCP protocol
    syscall

    # Save the socket file descriptor.
    # We'll use it in the next few syscalls.
    mov r12, rax


    # --- Create a socket address structure ---
    #
    # sockaddr_in {
    #     sin_family = AF_INET
    #     sin_port   = 8080
    #     sin_addr   = 0.0.0.0
    # }
    #
    # Binding to 0.0.0.0 means the server will accept
    # connections on any available network interface.

    mov word ptr [rip+sockaddr_in], 2
    mov word ptr [rip+sockaddr_in+2], 0x901F   # Port 8080 in network byte order
    mov dword ptr [rip+sockaddr_in+4], 0       # INADDR_ANY (0.0.0.0)
    mov qword ptr [rip+sockaddr_in+8], 0       # Unused padding


    # --- Bind the socket to port 8080 ---
    #
    # Without bind(), the kernel wouldn't know which
    # incoming connections belong to our server.

    mov rax, 49               # bind syscall
    mov rdi, r12              # socket file descriptor
    lea rsi, [rip+sockaddr_in]
    mov rdx, 16
    syscall


    # --- Start listening for incoming connections ---
    #
    # The socket is now placed into a listening state.

    mov rax, 50               # listen syscall
    mov rdi, r12
    mov rsi, 1                # backlog
    syscall


    # --- Wait for a client to connect ---
    #
    # The kernel handles the TCP handshake for us.
    # Once a client connects, accept() returns a new
    # file descriptor representing that client.

    mov rax, 43               # accept syscall
    mov rdi, r12
    xor rsi, rsi
    xor rdx, rdx
    syscall

    # Save the client socket file descriptor.
    mov r13, rax


    # At this point the TCP connection has been established.
    #
    # The client can now send an HTTP request.
    # Our job is simple:
    #
    #   1. Read the request.
    #   2. Decide how to respond.
    #   3. Send a response back.


    # --- Read the HTTP request ---
    #
    # The request bytes will be copied into recv_buffer.

    mov rax, 0               # read syscall
    mov rdi, r13             # client file descriptor
    lea rsi, [recv_buffer]
    mov rdx, 1024
    syscall


    # --- Send the HTTP response ---
    #
    # For now we always return the same response
    # regardless of what the client requested.

    mov rax, 1               # write syscall
    mov rdi, r13             # client file descriptor
    lea rsi, [rip+response]
    mov rdx, RESP_LEN
    syscall


    # --- Close the client connection ---
    #
    # This tells the client that we're done sending data.
    # Without this, tools like curl may continue waiting
    # for more data from the server.

    mov rax, 3               # close syscall
    mov rdi, r13
    syscall


    # --- Exit the program ---
    #
    # Our server only handles a single request.
    # After serving one client, we exit.

    mov rax, 60              # exit syscall
    mov rdi, 0
    syscall
