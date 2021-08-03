// main javascript file that handles all javacript activity

import { setUpGraph, renderGraph } from "./graph.js";
import {
  setUpAnimation,
  renderInfrastructure,
  renderPatientPosition,
  maxQueueLength,
} from "./animation.js";
import { graph } from "./graph2.js";

let pooled, numberPatientTypes;

// select containers for the animations
const animationUnpooled = d3.select(".animation-unpooled");
const animationPooled = d3.select(".animation-pooled");
//const graphUnpooled = d3.select(".graph-unpooled");

// select contatiner for graphs and append SVG to it
const svgGraphUnpooled = d3
  .select(".graph-unpooled")
  .append("svg")
  .attr("preserveAspectRatio", "xMinYMin meet")
  .attr("viewBox", `0 0 ${850} ${350}`);
const svgGraphPooled = d3
  .select(".graph-pooled")
  .append("svg")
  .attr("preserveAspectRatio", "xMinYMin meet")
  .attr("viewBox", `0 0 ${850} ${350}`);

// set up the basic animations
numberPatientTypes = 2;
setUpAnimation(animationUnpooled);
renderInfrastructure(animationUnpooled, numberPatientTypes, false);
setUpAnimation(animationPooled);
renderInfrastructure(animationPooled, numberPatientTypes, true);

// set up the basic graphs
//setUpGraph(graphUnpooled);
const graphUnpooled = graph()
  .margin({
    top: 40,
    right: 60,
    bottom: 10,
    left: 50,
  });
svgGraphUnpooled.call(graphUnpooled);

//setUpGraph(graphPooled);
const graphPooled = graph()
  .margin({
    top: 40,
    right: 60,
    bottom: 10,
    left: 50,
  });
svgGraphPooled.call(graphPooled);

// message handler for updating the unpooled animation
// all messages generated in Shiny
Shiny.addCustomMessageHandler("update-animation-unpooled", function (data) {
  //calculate positions in non-pooled state
  let positionX = 0;
  let positionY = 0;
  for (let i in data) {
    if (i == 0) {
      data[i].pos = -3;
      data[i].queue = 1;
    } else if (i == 1) {
      data[i].pos = -3;
      data[i].queue = 2;
    } else if (data[i].type == 1) {
      data[i].pos = positionX;
      data[i].queue = 1;
      positionX++;
    } else if (data[i].type == 2) {
      data[i].pos = positionY;
      data[i].queue = 2;
      positionY++;
    }
  }

  //check if doctor offices are empty, then remove
  if (!("id" in data[1])) {
    data.splice(1, 1);
  }
  if (!("id" in data[0])) {
    data.splice(0, 1);
  }

  renderPatientPosition(animationUnpooled, data, numberPatientTypes, false);
});

// message handler for updating the pooled animation
Shiny.addCustomMessageHandler("update-animation-pooled", function (data) {
  // calculate positions in pooled state
  let position = 0;
  for (let i in data) {
    if (i == 0) {
      data[i].pos = -3;
      data[i].queue = 1;
    } else if (i == 1) {
      data[i].pos = -3;
      data[i].queue = 2;
    } else {
      data[i].queue = Math.floor(position / maxQueueLength);
      data[i].pos = position - data[i].queue * maxQueueLength;
      position++;
    }
  }

  if (!("id" in data[1])) {
    data.splice(1, 1);
  }
  if (!("id" in data[0])) {
    data.splice(0, 1);
  }

  //console.log(data);
  renderPatientPosition(animationPooled, data, numberPatientTypes, true);
});

// message handler for updating unpooled graph
Shiny.addCustomMessageHandler("update-graph-unpooled", function (data) {
  svgGraphUnpooled.call(graphUnpooled.data(data));
});

// message handler for updating pooled graph
Shiny.addCustomMessageHandler("update-graph-pooled", function (data) {
  svgGraphPooled.call(graphPooled.data(data));
});

// get arrival and service rates on change
document.getElementById("arrivalRateX").onchange = outputUtilization;
document.getElementById("arrivalRateY").onchange = outputUtilization;
document.getElementById("serviceRateX").onchange = outputUtilization;
document.getElementById("serviceRateY").onchange = outputUtilization;

// output utilizations in the animations
function outputUtilization() {
  let arrivalRateX = parseFloat(document.getElementById("arrivalRateX").value);
  let arrivalRateY = parseFloat(document.getElementById("arrivalRateY").value);
  let serviceRateX = parseFloat(document.getElementById("serviceRateX").value);
  let serviceRateY = parseFloat(document.getElementById("serviceRateY").value);

  let utilizationUnpooledX = arrivalRateX / serviceRateX;
  let utilizationUnpooledY = arrivalRateY / serviceRateY;
  let probX = arrivalRateX / (arrivalRateX + arrivalRateY);
  let probY = arrivalRateY / (arrivalRateX + arrivalRateY);
  let utilizationPooled =
    (arrivalRateX + arrivalRateY) /
    (2 * (probX * serviceRateX + probY * serviceRateY));

  if (utilizationUnpooledX > 1) {
    utilizationUnpooledX = "> 1";
  } else {
    utilizationUnpooledX = utilizationUnpooledX.toPrecision(3);
  }
  if (utilizationUnpooledY > 1) {
    utilizationUnpooledY = "> 1";
  } else {
    utilizationUnpooledY = utilizationUnpooledY.toPrecision(3);
  }
  if (utilizationPooled > 1) {
    utilizationPooled = "> 1";
  } else {
    utilizationPooled = utilizationPooled.toPrecision(3);
  }

  animationUnpooled
    .select(".infrastructure")
    .selectAll(".green-utilization")
    .data([null])
    .join("text")
    .attr("class", "green-utilization")
    .attr("transform", `translate(0, ${20})`)
    .text(`Green utilization: ${utilizationUnpooledX}`);

  animationUnpooled
    .select(".infrastructure")
    .selectAll(".blue-utilization")
    .data([null])
    .join("text")
    .attr("class", "blue-utilization")
    .attr("transform", `translate(0, ${20 + 20})`)
    .text(`Blue utilization: ${utilizationUnpooledY}`);

  animationPooled
    .select(".infrastructure")
    .selectAll(".pooled-utilization")
    .data([null])
    .join("text")
    .attr("class", "pooled-utilization")
    .attr("transform", `translate(0, ${20})`)
    .text(`Utilization: ${utilizationPooled}`);
}
