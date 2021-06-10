function setUpAnimation() {
  const height = 320;
  const width = 850;

  //append svg to designated element
  let svg = d3
    .select(".animation") //.animation created in Shiny
    .append("svg")
    .attr("preserveAspectRatio", "xMinYMin meet")
    .attr("viewBox", `0 0 ${width} ${height}`);

  svg.append("image").attr("xlink:href", "animation_background.svg");
}

function renderAnimation(patients) {
  const xPosition = (d, i) =>
    d.hasOwnProperty("pos") ? (9 - d.pos) * 44 + 46 : 9; //62

  const yPosition = (d, i) => {
    if (d.type === "X" || d.type === "atX") {
      return 106; // + 16;
    } else if (d.type === "Y" || d.type === "atY") {
      return 106 + 144; // + 16;
    }
  };

  const colorScale = d3
    .scaleOrdinal()
    .domain(["X", "Y", "atX", "atY"])
    .range(["green", "steelblue"]);

  let svg = d3.select(".animation svg");

  const groups = svg.selectAll("g").data(patients, (d) => d.id);
  const groupsEnter = groups
    .enter()
    .append("g")
    .attr("transform", (d, i) => `translate(0, ${yPosition(d, i)})`);
  groupsEnter
    .merge(groups)
    .transition()
    .attr(
      "transform",
      (d, i) => `translate(${xPosition(d, i)}, ${yPosition(d, i)})`
    );
  groups
    .exit()
    .transition()
    .duration(500)
    .attr("transform", `translate(${754 + 25 - 16}, ${198 + 50 - 16})`)
    .remove();

  // Patient appearance
  groupsEnter
    .append("circle")
    .attr("cx", 16)
    .attr("cy", 16)
    .attr("r", 16)
    .attr("fill", (d) => colorScale(d.type));
  groupsEnter
    .append("circle")
    .attr("cx", 10.5)
    .attr("cy", 9.5)
    .attr("r", 1.5)
    .attr("fill", "black");
  groupsEnter
    .append("circle")
    .attr("cx", 21.5)
    .attr("cy", 9.5)
    .attr("r", 1.5)
    .attr("fill", "black");
  groupsEnter
    .append("rect")
    .attr("x", 6)
    .attr("y", 16)
    .attr("height", 10)
    .attr("width", 20)
    .attr("fill", "white");
  groupsEnter
    .append("line")
    .attr("x1", 0)
    .attr("y1", 12)
    .attr("x2", 6)
    .attr("y2", 17)
    .attr("stroke-width", 1)
    .attr("stroke", "white");
  groupsEnter
    .append("line")
    .attr("x1", 2)
    .attr("y1", 24)
    .attr("x2", 7)
    .attr("y2", 23)
    .attr("stroke-width", 1)
    .attr("stroke", "white");
  groupsEnter
    .append("line")
    .attr("x1", 26)
    .attr("y1", 17)
    .attr("x2", 32)
    .attr("y2", 12)
    .attr("stroke-width", 1)
    .attr("stroke", "white");
  groupsEnter
    .append("line")
    .attr("x1", 25)
    .attr("y1", 23)
    .attr("x2", 30)
    .attr("y2", 24)
    .attr("stroke-width", 1)
    .attr("stroke", "white");
  groupsEnter
    .append("text")
    .text((d) => d.pos)
    .attr("y", 60);

  /*const circles = svg.selectAll('circle')
        .data(patients, d => d.id);
      circles
        .enter().append('circle')
          .attr('cy', yPosition)
          .attr('r', 16 * Math.random() + 5)
          .attr('fill', d => colorScale(d.type))
        .merge(circles)
        .transition()
          .attr('cx', xPosition)
          .attr('cy', yPosition);
      circles.exit()
        .transition().duration(500)
        .attr('cx', 754 + 25)
        .attr('cy', 198 + 50)
        .remove();*/
}

setUpAnimation();
//renderAnimation();

Shiny.addCustomMessageHandler("update-waiting", function (data) {
  console.log(data);

  positionX = 0;
  positionY = 0;
  for (let i in data) {
    //console.log(data[i])
    if (data[i].type === "X") {
      data[i].pos = positionX;
      positionX++;
    } else if (data[i].type === "Y") {
      data[i].pos = positionY;
      positionY++;
    } else if (data[i].type === "atX") {
      data[i].pos = -3;
    } else if (data[i].type === "atY") {
      data[i].pos = -3;
    }
  }

  renderAnimation(data);
});
