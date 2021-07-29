import { setUpGraph, renderGraph } from "./graph.js";
import {
  setUpAnimation,
  renderInfrastructure,
  renderPatientPosition,
  maxQueueLength,
} from "./animation.js";
import { graph } from "./graph2.js";

let pooled, numberPatientTypes;

const animationUnpooled = d3.select(".animation-unpooled");
const animationPooled = d3.select(".animation-pooled");
const graphUnpooled = d3.select(".graph-unpooled");
const svgGraphPooled = d3
  .select(".graph-pooled")
  .append("svg")
  .attr("preserveAspectRatio", "xMinYMin meet")
  .attr("viewBox", `0 0 ${850} ${350}`);

numberPatientTypes = 2;
setUpAnimation(animationUnpooled);
renderInfrastructure(animationUnpooled, numberPatientTypes, false);
setUpAnimation(animationPooled);
renderInfrastructure(animationPooled, numberPatientTypes, true);
setUpGraph(graphUnpooled);

//setUpGraph(graphPooled);
const graphPooled = graph()
  //.height(350)
  //.width(850)
  .margin({
    top: 40,
    right: 60,
    bottom: 10,
    left: 50,
  })
  .title("Test");
svgGraphPooled.call(graphPooled);

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

  if (!("id" in data[1])) {
    data.splice(1, 1);
  }
  if (!("id" in data[0])) {
    data.splice(0, 1);
  }

  //console.log(data);
  renderPatientPosition(animationUnpooled, data, numberPatientTypes, false);
});

Shiny.addCustomMessageHandler("update-animation-pooled", function (data) {
  console.log(data);

  //numberPatientTypes = 2;



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

Shiny.addCustomMessageHandler("update-graph-unpooled", function (data) {
  renderGraph(graphUnpooled, data);
  //console.log(data);
});

Shiny.addCustomMessageHandler("update-graph-pooled", function (data) {
  svgGraphPooled.call(graphPooled.data(data));

  //renderGraph(graphPooled, data);
  //console.log(data);
});
