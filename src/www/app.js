import { setUpGraph, renderGraph } from "./graph.js";
import {
  setUpAnimation,
  renderInfrastructure,
  renderPatientPosition,
  maxQueueLength
} from "./animation.js";

let pooled, numberPatientTypes;

const animationUnpooled = d3.select(".animation-unpooled");
const animationPooled = d3.select(".animation-pooled");
const graphUnpooled = d3.select(".graph-unpooled");
const graphPooled = d3.select(".graph-pooled");

setUpAnimation(animationUnpooled);
setUpAnimation(animationPooled)
setUpGraph(graphUnpooled);
setUpGraph(graphPooled);

Shiny.addCustomMessageHandler("update-animation-unpooled", function (data) {
  //pooled = document.getElementById("pooled").checked;
  numberPatientTypes = 2;//document.getElementById("patientTypes").value;

  renderInfrastructure(animationUnpooled, numberPatientTypes, false);

  //calculate positions in non-pooled state
  let positionX = 0;
  let positionY = 0;
  for (let i in data) {
    if (data[i].type == 1) {
      data[i].pos = positionX;
      data[i].queue = 1;
      positionX++;
  } else if (data[i].type == 2) {
      data[i].pos = positionY;
      data[i].queue = 2;
      positionY++;
  } else if (data[i].type == -1) {
      data[i].pos = -3;
      data[i].queue = 1;
  } else if (data[i].type == -2) {
      data[i].pos = -3;
      data[i].queue = 2;
    }
  }

  //console.log(data);
  renderPatientPosition(animationUnpooled, data, numberPatientTypes, false);
});

Shiny.addCustomMessageHandler("update-animation-pooled", function (data) {
    numberPatientTypes = 2;

    renderInfrastructure(animationPooled, numberPatientTypes, true);

    // calculate positions in pooled state
    let position = 0;
    for (let i in data) {
      if (data[i].type == -1) {
        data[i].pos = -3;
        data[i].queue = 1;
    } else if (data[i].type == -2) {
        data[i].pos = -3;
        data[i].queue = 2;
      } else {
        data[i].queue = Math.floor(position / maxQueueLength);
        data[i].pos = position - data[i].queue * maxQueueLength;
        position++;
      }
    }


    //console.log(data);
    renderPatientPosition(animationPooled, data, numberPatientTypes, true);
});

Shiny.addCustomMessageHandler("update-graph-unpooled", function (data) {
  renderGraph(graphUnpooled, data);
  console.log(data);
});

Shiny.addCustomMessageHandler("update-graph-pooled", function (data) {
  renderGraph(graphPooled, data);
});
