$(document).ready(function(){    
  $("#player_well_div").delegate('#player_hit', 'click', player_hit);         
  $("#player_well_div").delegate('#player_stay', 'click', player_stay);         
  $("#player_well_div").delegate('#player_play_again', 'click', player_play_again);         
  $("#player_well_div").delegate('#player_place_bet', 'click', player_place_bet);         
});

function render_game(response_templates_json){
  var game_templates= eval('(' + response_templates_json + ')');        

  if (game_templates.player_game_status.length > 0)
    $('#player_current_game_status').replaceWith(game_templates.player_game_status);
  
  if (game_templates.dealer_game_status.length > 0)
    $('#dealer_current_game_status').replaceWith(game_templates.dealer_game_status);        
    
  if (game_templates.game_result.length > 0){
    $('#game_result').replaceWith(game_templates.game_result);        
    $('#game_result').hide();
    $('#game_result').fadeIn(2000);    
  }
}

function start_a_new_game(event){
  $.ajax({
    url:'/game/init',
    type:'POST'
  })
  .done(function(msg){        
    $('#game_screen').replaceWith(msg);      
    console.log("Ajax-ok.") 
  });      
}

function player_play_again(event){
  $.ajax({
    url:'/game/play_again',
    type:'POST'
  })
  .done(function(msg){
    $('#game_screen').replaceWith(msg);       
    $('#game_screen').hide();     
    $('#game_screen').fadeIn('slow'); 
  })  
}

function player_place_bet(event){    
  if (!validate_player_bet()){        
    $("#div_warning_place_bet").show();
    return false;
  }
  $('#place_bet_div').fadeOut('fast');
    
  $.ajax({
    url:'/game/place_bet',
    type:'POST',
    data: {bet: $("#input_bet").val()}
  })
  .done(function(msg){   
    $('#game_screen').replaceWith(msg);          
  }) 

}

function player_stay(event){
  $.ajax({
    url:'/player/stay',
    type:'POST'
  })
  .done(function(msg){    
    render_game(msg);      
  }) 
}

function player_hit(event){   
  $.ajax({
    url: '/player/hit',
    type: 'POST'        
  })
  .done(function(msg) {      
    render_game(msg);        
    console.log("Ajax-ok");
  }) 
}

function validate_player_bet(){
  var ret_flag = false ;  
  var player_bet = $("#input_bet").val();
  if ((Number(player_bet) <= 0) || isNaN(Number(player_bet))){        
    ret_flag = false;
  }
  else
    ret_flag = true;  
  return ret_flag;
}
