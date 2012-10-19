$ ->
  $('.button.delete').click ->
    $.ajax
      url: $(@).attr('href')
      type: 'DELETE'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        location.href = '/'
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
    false
