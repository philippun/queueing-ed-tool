const graphHeight = 320;
const graphWidth = 1000;
const graphMargin = { top: 20, right: 20, bottom: 25, left: 30};
const graphInnerWidth = graphWidth - graphMargin.left - graphMargin.right;
const graphInnerHeight = graphHeight - graphMargin.top - graphMargin.bottom;

function setUpAnimation() {
  const height = 320;
  const width = 850;

  //append svg to designated element
  let svg = d3
    .select(".animation") //.animation div created in Shiny
    .append("svg")
    .attr("class", "animation-svg")
    .attr("preserveAspectRatio", "xMinYMin meet")
    .attr("viewBox", `0 0 ${width} ${height}`);

  svg.append("image").attr("xlink:href", "animation_background.svg");
}

function setUpGraph() {
    let svg = d3
      .select(".graph")
      .append("svg")
      .attr("preserveAspectRatio", "xMinYMin meet")
      .attr("viewBox", `0 0 ${graphWidth} ${graphHeight}`);

     let g = svg.append("g")
        .attr("class", "graph-group")
        .attr("transform", `translate(${graphMargin.left},${graphMargin.top})`);
}

function renderAnimation(patients) {
  const xPosition = (d, i) =>
    d.hasOwnProperty("pos") ? (9 - d.pos) * 44 + 46 : 9; //62

  const yPosition = (d, i) => {
    return 106 + d.queue * 144;

    /*if (d.type === "X" || d.type === "atX") {
      return 106; // + 16;
    } else if (d.type === "Y" || d.type === "atY") {
      return 106 + 144; // + 16;
  }*/
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
    .text((d) => d.id)
    .attr("y", 60);

  // pattern first used to create circles for the patients
  // Not needed anymore but for reference
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

function renderGraph(data) {
    const xValue = (d, i) => i;
    const yValue = d => d.avgPatientsInQueue;

    const xScaleBand = d3.scaleBand()
        .domain(d3.range(0, 99))
        .range([0, graphInnerWidth])
        .padding(0.1);

    const ScalePoint = d3.scalePoint()
        .domain(data.map(xValue))
        .range([0, innerWidth])
        .padding(0.5);

    const yScale = d3.scaleLinear()
        .domain([0, 22])
        .range([graphInnerHeight, 0]);

    let graph = d3.select(".graph-group")

    let avgPatientsInQueue = graph.selectAll("rect")
        .data(data)
    avgPatientsInQueue
        .enter().append("rect")
            .attr("fill", "gray")

        .merge(avgPatientsInQueue)
            .attr("x", (d, i) => xScaleBand(i))
            .attr("width", xScaleBand.bandwidth())
            .attr("y", d => yScale(yValue(d)))
            .attr("height", d => yScale(0) - yScale(yValue(d)));
    avgPatientsInQueue.exit().remove();
}

setUpAnimation();
setUpGraph();

Shiny.addCustomMessageHandler("update-waiting", function (data) {
  console.log(data);

  if (document.getElementById('pooled').checked) {
      d3.select(".animation-svg").selectAll(".wall-image")
        .data([1]).enter()
        .append("image")
        .attr("xlink:href", "wall.svg")
        .attr("class", "wall-image")
        .attr("x", 480)
        .attr("y", 238);

      // position if pooled
      position = 0;
      for (let i in data) {
          if (data[i].type === "atX") {
            data[i].pos = -3;
            data[i].queue = 0;
          } else if (data[i].type === "atY") {
            data[i].pos = -3;
            data[i].queue = 1;
        } else {
            data[i].queue = position < 10 ? 0 : 1;
            data[i].pos = position - (data[i].queue * 10);
            position++;
        }
      }
  } else {
      d3.select(".wall-image").remove();

      // position if not pooled
      positionX = 0;
      positionY = 0;
      for (let i in data) {
        //console.log(data[i])
        if (data[i].type === "X") {
          data[i].pos = positionX;
          data[i].queue = 0;
          positionX++;
        } else if (data[i].type === "Y") {
          data[i].pos = positionY;
          data[i].queue = 1;
          positionY++;
        } else if (data[i].type === "atX") {
          data[i].pos = -3;
          data[i].queue = 0;
        } else if (data[i].type === "atY") {
          data[i].pos = -3;
          data[i].queue = 1;
        }
    }
  }

  renderAnimation(data);
});

Shiny.addCustomMessageHandler("update-graph", function(data) {
    console.log(data);

    renderGraph(data);
});
