require 'rubygems'
require 'sinatra'
require 'pry' 


use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'your_secret' 
#set :sessions, true
#set :session_secret, 'This is a secret key'
  
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
  Delear_picture = "<img src='http://www.gravatar.com/avatar/7591cadea2328c5362c032df51246020' alt='delear picture' class='img-circle'/>"
  Bet = 100
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
    # prepare Deck    
    if reset
      session[:deck] = []
      session[:account] = 1000
      session[:count_draw] = 0
      session[:count_lose] = 0
      session[:count_win]  = 0
    else
      session[:deck] ||= []
      session[:account] ||= 1000
      session[:count_draw] ||= 0
      session[:count_lose] ||= 0
      session[:count_win]  ||= 0
    end    
    session[:player_win_or_lose] = ""
    
    deck_cards = session[:deck] 
    Deck.supplemnt_cards!(deck_cards) if !Deck.is_cards_enough?(deck_cards)  
    
    # deale cards - to player   
    session[:player_hand]=[]
    2.times { session[:player_hand] << Deck.flick_a_card!(session[:deck]) }
    
    # deale cards - to delear
    session[:delear_hand]=[]
    2.times { session[:delear_hand] << Deck.flick_a_card!(session[:deck]) }

    session[:player_stay] = false
  end

  def hit_card(my_hand)    
      my_hand <<  Deck.flick_a_card!(session[:deck])          
  end

  def calculate_total(my_hand)    
    total = 0
    suit_Ace_count = 0    
    return total if !my_hand    
        
    my_hand.each do |c|   
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

  def is_blackjack?(my_hand)         
    return false if !my_hand    
    my_hand.count == 2 && calculate_total(my_hand) ==21        
  end
  
  def is_twentyone?(my_hand)     
    return false if !my_hand
    my_hand.count > 2 && calculate_total(my_hand) == 21
  end
  
  def is_bursted?(my_hand)      
    return false if !my_hand
    calculate_total(my_hand) > 21
  end

  def is_total_over_17?(my_hand)
    false if !my_hand
    calculate_total(my_hand) > 17
  end

  def get_cards_status(my_hand)
    if is_blackjack?(my_hand)
      "blackjack"
    elsif is_twentyone?(my_hand) 
      "twentyone"
    elsif is_bursted?(my_hand)
      "bursted"
    elsif is_total_over_17?(my_hand)
      "total_over_17"
    else
      ""
    end
  end

  def is_delear_turn?        
    (@player_stay || is_bursted?(@player_hand) || is_blackjack?(@player_hand) || is_twentyone?(@player_hand)) ? true : false      
  end

  def player_win_draw_lose(player_hand,delear_hand)    
    if is_blackjack?(delear_hand)
      if is_blackjack?(player_hand)
       return 0
      else
        return -1
      end
    end

    if is_twentyone?(delear_hand)
      if is_blackjack?(player_hand)
        return 1
      elsif is_twentyone?(player_hand)
        return 0  
      else
        return -1
      end        
    end

    if is_bursted?(delear_hand)
      if is_bursted?(player_hand)
        return 0
      else
        return 1
      end
    end

    if (calculate_total(delear_hand) < 21)
      if is_bursted?(player_hand)
        return -1
      elsif (is_blackjack?(player_hand) || is_twentyone?(player_hand))
        return 1
      else
        return -1 if (calculate_total(delear_hand) > calculate_total(player_hand)) 
        return 0 if (calculate_total(delear_hand) == calculate_total(player_hand)) 
      return 1 if (calculate_total(delear_hand) < calculate_total(player_hand)) 
      end
    end
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
      erb :'player/info'
  end
end

post '/player/create' do  
  create_player    
  redirect 'game/welcome'
end

post '/player/hit' do 
  @player_hand = session[:player_hand]
  hit_card(@player_hand)      
  if is_bursted?(@player_hand) || is_blackjack?(@player_hand) || is_twentyone?(@player_hand) 
    session[:player_stay] = true
  end
  redirect :'game'
end

post '/player/stay' do     
  session[:player_stay] = true
  redirect :'game'
end

get '/game' do  
  
  @player_name = session[:player_name]    
  redirect '/player' if !@player_name

  @deck = session[:deck]    
  @player_hand = session[:player_hand]     
  @delear_hand = session[:delear_hand]      
  redirect '/game/init' if !@deck || !@player_hand || !@delear_hand

  @player_total = calculate_total(@player_hand)    
  @player_cards_status= get_cards_status(@player_hand) unless !@player_hand
  @player_stay = session[:player_stay]
        
  # check if it's delear's turn or not
  if is_delear_turn?            
      while true
        @delear_cards_status= get_cards_status(@delear_hand) unless !@delear_hand          
        if @delear_cards_status.empty?
          #delear_auto_hit_cards(@delear_hand)
          hit_card(@delear_hand)      
        else
          break
        end
      end         
      @delear_total = calculate_total(@delear_hand)          
            
      # handle cards comparision of both delear and player in erb.
      if session[:player_win_or_lose] && session[:player_win_or_lose].empty?         
        case player_win_draw_lose(@player_hand,@delear_hand)
        when 0
          session[:player_win_or_lose]  = "Draw game."
          session[:count_draw] += 1
        when 1
          session[:player_win_or_lose]  = "Congradulation, you win!"
          session[:account] += Game::Bet
          session[:count_win] += 1
        when -1
          session[:player_win_or_lose]  = "Sorry, you lose!"
          session[:account] -= Game::Bet
          session[:count_lose] += 1
        end     
      end      
      @player_win_or_lose =  session[:player_win_or_lose] 
  end
  
  @account = session[:account]     
  
  erb :'game/play'
end

get '/game/init' do
  initial_game(true)
  redirect :'game'
end

get '/game/play_again' do
  session[:press_play_again] = true
  session[:is_delear_checked] = false
  initial_game
  redirect :'game'
end

get '/game/welcome' do  
  if !session[:player_name] || session[:player_name].empty? 
    #halt erb(:'player/create')
    redirect 'player'
  else
    initial_game(true)
    @player_name = session[:player_name]
    @account = session[:account]
    erb :'game/welcome'
  end
end

#------------------------>>




