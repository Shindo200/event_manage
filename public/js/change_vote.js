$(function() {
  $('button.up_vote').click(function() {
    var current_row = $(this).parents('tr');
    var event_id = current_row.find('div.vote input[name=event_id]').val();
    $.post('/' + event_id + '/vote/up', null, function(data) {
      current_row.find('div.vote span.count_vote').text(data['vote'] + ' pt');
    });
  });

  $('button.down_vote').click(function() {
    var current_row = $(this).parents('tr');
    var event_id = current_row.find('div.vote input[name=event_id]').val();
    $.post('/' + event_id + '/vote/down', null, function(data) {
      current_row.find('div.vote span.count_vote').text(data['vote'] + ' pt');
    });
  });
});
