const $ = (el)=>{
    return document.querySelector(el);
}
const typeEffect = (el , string)=>{
    const text = string;
    const arrayText = text.split("") ;
    let i = 0;
    let type = setInterval(()=>{
        $(el).innerHTML += arrayText[i];
        i++;
        if(i == arrayText.length){
            clearInterval(type);
        }
    },100);
}
typeEffect("#title","Mirava");
setTimeout(()=>{
    typeEffect("#caption","Mirava is a curated list of Iranian package mirrors, providing reliable and fast access to essential software resources within Iran.")
},1000)