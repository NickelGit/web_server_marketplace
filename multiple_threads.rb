# ab -n 10000 -c 100 -p ./section_one/ostechnix.txt localhost:1234/
# head -c 100000 /dev/urandom > section_one/ostechnix_big.txt

require 'socket'
require 'mime/types'

require './lib/response'
require './lib/request'
MAX_EOL = 2

socket = TCPServer.new(ENV['HOST'], ENV['PORT'])

def handle_request(request_text, client)
  request  = Request.new(request_text)
  path = request.path
  p request

  response = if path == '/'
               Response.new(code: 200, data: 'Hello world!')
             else
               file_response(path)
             end
    

  response.send(client)

  client.shutdown
end

def file_response(path)
  # p path
  file = File.open(".#{path}")
  file_data = file.read
  file.close

  ext = File.extname(path)
  mime_type = MIME::Types.type_for(ext)
  content_type = "Content-Type: #{mime_type.first.content_type}"
  # puts "#{client.peeraddr[3]} #{request.path}"

  Response.new(code: 200, data: file_data, headers: [content_type])
rescue Exception => e
  puts "Error: #{e}"
 
  code = 500
  code = 403 if e.class == Errno::EACCES
  code = 404 if e.class == Errno::ENOENT

  Response.new(code: code, data: e.message)
end

def handle_connection(client)
  puts "Getting new client #{client}"
  request_text = ''
  eol_count = 0

  loop do
    buf = client.recv(1)
    puts "#{client} #{buf}"
    request_text += buf

    eol_count += 1 if buf == "\n"

    if eol_count == MAX_EOL
      handle_request(request_text, client)
      break
    end

    # sleep 1
  end
rescue => e
  puts "Error: #{e}"

  response = Response.new(code: 500, data: "Internal Server Error")
  response.send(client)

  client.close
end

puts "Listening on #{ENV['HOST']}:#{ENV['PORT']}. Press CTRL+C to cancel."

loop do
  Thread.start(socket.accept) do |client|
    handle_connection(client)
  end
end

