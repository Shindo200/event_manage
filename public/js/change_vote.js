$(function() {
  // vote 値を増やす
  $('button.up_vote').on('click', { 'action': 'up' }, post_change_vote);

  // vote 値を減らす
  $('button.down_vote').on('click', { 'action': 'down' }, post_change_vote);

  function post_change_vote(e) {
    var current_row = $(this).parents('tr');
    var event_id = current_row.find('div.vote input[name=event_id]').val();
    var url = '/' + event_id + '/vote/' + e.data.action;

    $.post(url, null, function(data) {
      // 更新後の vote 値に画面に表示する
      current_row.find('div.vote span.count_vote').text(data['vote'] + ' pt');
    });
  }
});
