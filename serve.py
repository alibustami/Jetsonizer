from livereload import Server

server = Server()

server.watch('*.html')
server.watch('*.css')

server.serve(root='.', port=5500)
