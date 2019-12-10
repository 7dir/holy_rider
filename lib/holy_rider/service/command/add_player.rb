# frozen_string_literal: true

module HolyRider
  module Service
    module Command
      class AddPlayer
        def initialize(command, message_type)
          @command = command
          @message_type = message_type
          @redis = HolyRider::Application.instance.redis
        end

        def call
          message = @command[@message_type]['text'].split(' ')
          username = message[1]
          trophy_account = message[2]
          Player.create(telegram_username: username)
          return successful_message unless trophy_account

          Player.find(telegram_username: username).update(trophy_account: trophy_account,
                                                          on_watch: true)
          @redis.sadd('holy_rider:watcher:players', trophy_account)
          @redis.set("holy_rider:watcher:players:initial_load:#{trophy_account}", 'initial')

          successful_message
        end

        private

        def successful_message
          ["#{username} создан"]
        end
      end
    end
  end
end