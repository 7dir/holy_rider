# frozen_string_literal: true

class Game < Sequel::Model
  Game.plugin :timestamps, update_on_create: true

  one_to_many :game_acquisitions
  one_to_many :trophies
  many_to_many :players, left_key: :game_id, right_key: :player_id, join_table: :game_acquisitions

  dataset_module do
    # TODO: try to combine datasets
    def find_game(title, platform: nil)
      unless platform
        return where(title: /^#{title}*/i)
               .left_join(:game_acquisitions, game_id: :id)
               .order(:last_updated_date)
               .reverse
               .limit(1)
               .first
      end

      where(title: /^#{title}*/i, platform: platform)
        .left_join(:game_acquisitions, game_id: :id)
        .order(:last_updated_date)
        .reverse
        .limit(1)
        .first
    end

    def find_exact_game(title, platform)
      where(title: title, platform: platform)
        .left_join(:game_acquisitions, game_id: :id)
        .limit(1)
        .first
    end

    def find_relevant_game(title, platform: nil)
      unless platform
        return where(title: /.*#{title}*/i)
               .left_join(:game_acquisitions, game_id: :id)
               .order(:last_updated_date)
               .reverse
               .limit(1)
               .first
      end

      where(title: /.*#{title}*/i, platform: platform)
        .left_join(:game_acquisitions, game_id: :id)
        .order(:last_updated_date)
        .reverse
        .limit(1)
        .first
    end

    def find_relevant_games(title)
      where(title: /^#{title}*/i)
        .left_join(:game_acquisitions, game_id: :id)
        .order(:last_updated_date)
        .reverse
        .limit(10)
        .map { |record| record.title + " #{record.platform}" }
    end

    # TODO: rename or combine
    def find_relevant_games_2(title, limit)
      where(title: /.*#{title}*/i)
        .left_join(:game_acquisitions, game_id: :id)
        .order(:last_updated_date)
        .reverse
        .limit(limit)
        .map { |record| record.title + " #{record.platform}" }
    end
  end

  def self.relevant_games(title, message)
    first_games = find_relevant_games(title).uniq
    second_games = []
    query_size = first_games.size
    second_games = find_relevant_games_2(title, 10 - query_size).uniq if query_size < 10

    player = message['message']['from']['username']
    redis = HolyRider::Application.instance.redis
    all_games = (first_games << second_games).flatten.uniq
    all_games.each_with_index do |game_title, index|
      redis.set("holy_rider:top:#{player}:games:#{index + 1}", game_title)
      redis.sadd("holy_rider:top:#{player}:games", "holy_rider:top:#{player}:games:#{index + 1}")
    end

    all_games
  end

  def self.find_game_from_cache(player, index)
    redis = HolyRider::Application.instance.redis
    game = redis.get("holy_rider:top:#{player}:games:#{index}")
    return unless game

    game_title = game.split(' ')[0..-2].join(' ')
    game_platform = game.split(' ').last
    redis.smembers("holy_rider:top:#{player}:games").each do |key|
      redis.del(key)
    end
    top_game(game_title, platform: game_platform, exact: true) if game_title
  end

  def self.top_game(title, platform: nil, exact: false)
    game = if exact
             find_exact_game(title, platform)
           else
             find_game(title, platform: platform) || find_relevant_game(title, platform: platform)
           end
    return unless game

    game_id = game.values[:game_id]
    progresses = GameAcquisition.find_progresses(game_id)
    players_with_platinum = players_with_platinum_trophy(game_id)
    {
      game: game,
      progresses: progresses,
      platinum: players_with_platinum
    }
  end

  def self.players_with_platinum_trophy(game_id)
    find(id: game_id).trophies.find { |trophy| trophy.trophy_type == 'platinum' }&.players
  end
end
