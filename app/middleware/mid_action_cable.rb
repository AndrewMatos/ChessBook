class MidActionCable
	def initialize(app, options = {})
		@app = app
	end

	def call(env)
		if ::WebSocket::Driver.Websocket?(env)
			ActionCable.server.call(env)
		else
			@app.call(env)
		end
	end
end