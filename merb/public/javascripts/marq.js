function json(text){
  var data;
  eval("data = " + text);
  return(data);
}

function tag(name){
  return($('<' + name + '></' + name + '>'));
}

function random_name(){
  return(Math.floor(Math.random() * 10000000));
}

function percent(e, elem){
  var top = $(elem).offset().top;
  var mtop = e.pageY;
  var vsize = $(elem).height();
  var percent = (mtop - top) / vsize;

  return(percent);
}


function findPos(obj){
  var curleft = curtop = 0;
  if (obj.offsetParent) {
    do {
      curleft += obj.offsetLeft;
      curtop += obj.offsetTop;
    } while (obj = obj.offsetParent);
  }
  return [curleft,curtop];
}

function fit_window(elem,margin){
   var height;
   height = $(window).height() - findPos(elem[0])[1] - margin;
   elem[0].style.height = height.toString() + "px";
}

function clear_textareas(){
  $('textarea').after('<a class="clear textarea_link" href="#">[clear]</a>');
  $('a.clear').click(
    function(){
      $(this).prev().attr('value','')
      return(false);
    })
}  

function post(URL, PARAMS, NEW_WINDOW) {
  var temp=document.createElement("form");
  temp.action=URL;
  temp.method="POST";
  temp.style.display="none";

  if (NEW_WINDOW){
    temp.target = "_blank";
  }

  for(var x in PARAMS) {
    var opt=document.createElement("textarea");
    opt.name=x;
    opt.value=PARAMS[x];
    temp.appendChild(opt);
  }
  document.body.appendChild(temp);
  temp.submit();
  return temp;
}
