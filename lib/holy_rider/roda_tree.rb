# frozen_string_literal: true

module HolyRider
  class RodaTree < Roda
    plugin(:not_found) { { error: 'Not found' } }

    route do |r|
      r.root do
        'The RODA root'
      end

      r.on 'welcome' do
        'hello world'
      end

      r.on 'favicon.ico' do
        '?'
      end

      # TODO: delete telegram routes before release
      r.on 'get_updates' do
        HolyRider::Service::ChatUpdateService.new.call.to_json
      end

      r.on 'send_message' do
        HolyRider::Service::SendChatMessageService.new(chat_id: ENV['PS_CHAT_ID'], message: 'Test').call.to_json
      end
    end
  end
end
