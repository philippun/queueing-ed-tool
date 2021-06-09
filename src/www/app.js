function setUpAnimation() {
    const height = 320;
    const width = 960;

    //append svg to designated element
    let svg = d3.select(".animation") //.animation created in Shiny
        .append("svg")
          .attr("preserveAspectRatio", "xMinYMin meet")
          .attr("viewBox", `0 0 ${width} ${height}`);

    svg.append("image")
        .attr("xlink:href","animation_background.svg")
}

function renderAnimation() {

}

setUpAnimation();
