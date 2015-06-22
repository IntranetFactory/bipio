### Bastion 

A helper class. Manages work taken from the job queue.

	rabbit = require 'rabbit.js'
	events = require 'events'
	Bip = require '../models/bips'
	Q = require 'q'
	Rx = require 'rx'

	class Bastion extends events.EventEmitter

		constructor: (app) ->
			self = @

			self.queue = rabbit.createContext app.config.amqp.url

			self.queue.on 'ready', () ->
				console.log "RabbitMQ Connected"

				self.pub = self.queue.socket('PUSH')
				self.sub = self.queue.socket('WORKER', {prefetch: 1, persistent: true})

				#self.broker = Rx.Observable.fromEvent self.sub, "data"

###### `error`

Used as second argument to [Rx.Observer.create](https://github.com/Reactive-Extensions/RxJS/blob/master/doc/api/core/observer.md#rxobservercreateonnext-onerror-oncompleted) when subscribing to the job queue.

				self.error = (err) -> 
					console.error "Graph Error: #{err.msg}".red

###### `complete`

Used as third argument to [Rx.Observer.create](https://github.com/Reactive-Extensions/RxJS/blob/master/doc/api/core/observer.md#rxobservercreateonnext-onerror-oncompleted) when subscribing to the job queue.

				self.complete = () -> 
					console.log "Worker Idle.".yellow

###### `next`

Used as first argument to [Rx.Observer.create](https://github.com/Reactive-Extensions/RxJS/blob/master/doc/api/core/observer.md#rxobservercreateonnext-onerror-oncompleted) when subscribing to the job queue.

				self.next = (buf) ->
					self.sub.ack()
					bip = new Bip(JSON.parse(buf.toString()))
					bip.start()
					app.database.update "bips", bip.id, { active: true }, (err, result) ->
						if err
							throw new Error err
						else
							app.dialog "Bip ##{result.id} is now active."
							app.activeChildren.push result
						
###### `addJob`

Adds a bip object representation to the AMQP exchange.

				self.broker.addJob = (bip) ->
					deferred = Q.defer()

					self.sub.connect 'bips', () ->
						self.pub.connect 'bips', () ->
							self.pub.write JSON.stringify(bip), 'utf8'
							deferred.resolve true

					deferred.promise

				#self.worker = Rx.Observer.create self.next, self.error, self.complete
				self.sub.on "data", self.next
				#self.broker.subscribe self.worker

			self.queue.on 'error', (err) ->
				console.log err

			return @

	module.exports = Bastion