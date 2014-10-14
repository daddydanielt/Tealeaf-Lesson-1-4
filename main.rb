require 'rubygems'
require 'sinatra'
require 'json/ext' # to use the C based extension instead of json/pure
require 'pry' 

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'your_secret' 

class Card 
  COVER ="/images/cards/cover.jpg" 
  class << self
    def to_img_src(card)   
      # card == [suit,number]
      "/images/cards/"+card[0].downcase+"_"+card[1].downcase+".jpg"
    end
  end
end

class Deck
  DECK = 1
  class << self
    def flick_a_card!(cards)
      supplemnt_cards!(cards) if !is_cards_enough?(cards)        
      cards.shift    
    end

    def is_cards_enough?(cards)
      (cards.count <  Deck::DECK * 52 / 2) ? false : true
    end

    def supplemnt_cards!(cards)              
      s=['Spades','Hearts','Diamonds','Clubs']
      n=['Ace','2','3','4','5','6','7','8','9','10','Jack','Queen','King']        
      c = (s.product(n) * Deck::DECK)
          .shuffle    
      cards.concat(c)    
    end    
  end
end

class Game
  Dealer_picture = "<img src='http://www.gravatar.com/avatar/7591cadea2328c5362c032df51246020' alt='dealer picture' class='img-circle'/>"
  Bet = 100

  def self.hit_card(my_hand, deck)              
    my_hand << Deck.flick_a_card!(deck)          
  end

end

class GameStatus

  attr_accessor :name, :hand

  def self.is_dealer_turn?(player_game_satatus)
    player_game_satatus.is_player_hit_stay? || player_game_satatus.is_busted? || player_game_satatus.is_blackjack? || player_game_satatus.is_twentyone?
  end

  def self.player_vs_dealer(player_hand, dealer_hand)
    return 0 if player_hand.is_blackjack? && dealer_hand.is_blackjack? 
    return 1 if player_hand.is_blackjack? && !dealer_hand.is_blackjack?
    return 0 if player_hand.is_twentyone? && dealer_hand.is_twentyone?
    return -1 if player_hand.is_twentyone? && dealer_hand.is_blackjack?    
    return 1 if player_hand.is_twentyone? && !(dealer_hand.is_twentyone? || dealer_hand.is_blackjack?)
    return -1 if player_hand.is_busted? 
    return 1 if dealer_hand.is_busted? && player_hand.hand_total < 21
    return -1 if (dealer_hand.is_twentyone? || dealer_hand.is_blackjack?) && player_hand.hand_total < 21              
    return 0 if (player_hand.hand_total == dealer_hand.hand_total) && player_hand.hand_total < 21
    return -1 if (player_hand.hand_total < dealer_hand.hand_total) && player_hand.hand_total < 21      
    return 1 if (player_hand.hand_total > dealer_hand.hand_total) && player_hand.hand_total < 21
  end

  def initialize(params = {})
    @name = params[:name]
    @hand = params[:hand]        
  end

  def hand_total
    total = 0
    suit_Ace_count = 0    
    return total if !@hand    
        
    @hand.each do |c|   
      case c[1] 
        when "Jack","Queen","King" 
          total += 10
        when "Ace"
          total += 11
          suit_Ace_count += 1
        else 
          total += c[1].to_i          
      end
    end   
    
    suit_Ace_count.times do 
      break if total <= 21
      total -= 10
    end       
    return total
  end

  def is_blackjack?            
    @hand && (@hand.count == 2 && self.hand_total ==21)
  end
  
  def is_twentyone?       
    @hand && (@hand.count > 2 && self.hand_total == 21)
  end
  
  def is_busted?         
    @hand && (self.hand_total > 21)
  end

  def is_equal_or_greater_than_17?    
    @hand && (self.hand_total >= 17)
  end
  
  def hand_status
    return "blackjack" if is_blackjack?
    return "twentyone" if is_twentyone?
    return "busted" if is_busted?
    return "total_over_17" if is_total_over_17?  
    return ""
  end
end

class PlayerGameSatatus < GameStatus
  attr_accessor :bet, :account
  def initialize(params={})  
    super(params)
    @account = params[:account]
    @bet = params[:bet]    
    @is_player_hit_stay = params[:is_player_hit_stay]
  end

  def is_player_hit_stay?    
    @is_player_hit_stay
  end  
end
  
#------------------------>>
helpers do 

  def create_player
    if params[:player_name].empty?
      halt erb(:'player/create')
    else
      session[:player_name] = params[:player_name]              
    end
  end

  def initial_game (reset = false)               
    session[:deck] ||= []
    session[:account] ||= 1000
    session[:bet]  = -1
    session[:count_draw] ||= 0
    session[:count_lose] ||= 0
    session[:count_win]  ||= 0

    # reset whole game
    if reset
      session[:deck] = []
      session[:account] = 1000
      session[:bet] = -1
      session[:count_draw] = 0
      session[:count_lose] = 0
      session[:count_win]  = 0        
    end    
    
    session[:is_player_hit_stay] = false
    session[:player_win_or_lose] = ""

    Deck.supplemnt_cards!(session[:deck]) if !Deck.is_cards_enough?(session[:deck])  

    # deale cards to player       
    session[:player_hand] = []
    2.times { session[:player_hand] << Deck.flick_a_card!(session[:deck]) }
    
    # deale cards to dealer
    session[:dealer_hand] = []
    2.times { session[:dealer_hand] << Deck.flick_a_card!(session[:deck]) }

  end
      
  def dealer_game_status_erb
    dealer_game_status_template = erb :'game/dealer_game_status', :layout => false
    dealer_game_status_template ||= ""
  end

  def player_game_status_erb
    player_game_status_template = erb :'game/player_game_status', :layout => false                       
    player_game_status_template ||= ""
  end

  def place_bet_erb
     erb :'game/place_bet', :layout => false 
  end

  def game_result_erb    
    if @player_game_status.is_player_hit_stay? \
       || @player_game_status.is_blackjack? \
       || @player_game_status.is_twentyone? \
       || @player_game_status.is_busted?           
      erb :'game/game_result', :layout => false
    else
      ""
    end
  end

  def game_erb
    {:dealer_game_status => dealer_game_status_erb,\
     :player_game_status => player_game_status_erb,\
     :bet => place_bet_erb,\
     :game_result => game_result_erb}
  end

  def game_info_refresh
    player_game_status = PlayerGameSatatus.new({:name => session[:player_name],\
                                             :hand => session[:player_hand],\
                                             :account => session[:account],\
                                             :bet => session[:bet],\
                                             :is_player_hit_stay => session[:is_player_hit_stay]})

    dealer_game_status = GameStatus.new({:name => "Daniel Tseng", :hand => session[:dealer_hand]})
        
    

    if GameStatus.is_dealer_turn?(player_game_status)  
      while true                                             
        if dealer_game_status.is_blackjack? || dealer_game_status.is_twentyone?\
           || dealer_game_status.is_busted? || dealer_game_status.is_equal_or_greater_than_17?\
           || player_game_status.is_busted? 
          break                                  
        end
        Game.hit_card(session[:dealer_hand], session[:deck])
      end
    end

    if player_game_status.is_player_hit_stay? \
       || player_game_status.is_blackjack? \
       || player_game_status.is_twentyone? \
       || player_game_status.is_busted?
      case GameStatus.player_vs_dealer(player_game_status, dealer_game_status)
      when 0
        player_win_or_lose = "Draw game."
      when -1
        player_win_or_lose = "Sorry, you lose."
        session[:account] -= session[:bet]        
      when 1
        player_win_or_lose = "Congratulation, you win."
        session[:account] += session[:bet]
      end
      player_game_status.account = session[:account]
    else
      player_win_or_lose = ""
    end

    {:player_game_status => player_game_status,\
     :dealer_game_status => dealer_game_status,\
     :player_win_or_lose => player_win_or_lose}
  end

end

#------------------------>>

get '/' do 
  session.clear  
  redirect :game
end

get '/player' do
  @player_name = session[:player_name] || ''
  @account = session[:account] || 0         
  @count_draw = session[:count_draw] || 0 
  @count_lose = session[:count_lose] || 0
  @count_win = session[:count_win] || 0

  if !@player_name || @player_name.empty?      
      erb :'player/create'
  else
      redirect '/game'
  end
end

post '/player/create' do  
  create_player    
  redirect 'game/welcome'
end

post '/player/hit' do     
  Game.hit_card(session[:player_hand], session[:deck])  
  game_info = game_info_refresh
  @player_game_status = game_info[:player_game_status]
  @dealer_game_status = game_info[:dealer_game_status]
  @player_win_or_lose = game_info[:player_win_or_lose]   
  game_erb.to_json
end

post '/player/stay' do     
  session[:is_player_hit_stay] = true  
  # I am here.
  #-> determine player win_or_lose
  #-> calculate account  
  game_info = game_info_refresh
  @player_game_status = game_info[:player_game_status]
  @dealer_game_status = game_info[:dealer_game_status]
  @player_win_or_lose = game_info[:player_win_or_lose]   
  game_erb.to_json
end

get '/game/welcome' do  
  if !session[:player_name] || session[:player_name].empty? 
    redirect 'player'
  else
    initial_game(true)
    @player_name = session[:player_name]
    @account = session[:account]
    erb :'game/welcome'
  end
end

get '/game/start_a_new_game' do
  initial_game(true)
  redirect '/game'
end

get '/game' do  
  #--->
  @player_name = session[:player_name]    
  redirect '/player' if !@player_name
  @deck = session[:deck]    
  @player_hand = session[:player_hand]     
  @dealer_hand = session[:dealer_hand]      
  redirect '/game/init' if !@deck || !@player_hand || !@dealer_hand
  #--->  
  
  game_info = game_info_refresh
  @player_game_status = game_info[:player_game_status]
  @dealer_game_status = game_info[:dealer_game_status]
  @player_win_or_lose = game_info[:player_win_or_lose] 
  erb :'game/play'  
end

post '/game/play_again' do        
  initial_game  
  game_info = game_info_refresh
  @player_game_status = game_info[:player_game_status]
  @dealer_game_status = game_info[:dealer_game_status]
  @player_win_or_lose = game_info[:player_win_or_lose]   
  erb :'game/play'  
end

post '/game/place_bet' do     
  session[:bet] = params[:bet].to_i  
  game_info = game_info_refresh
  @player_game_status = game_info[:player_game_status]
  @dealer_game_status = game_info[:dealer_game_status]
  @player_win_or_lose = game_info[:player_win_or_lose]  
  erb :'game/play'  
end





