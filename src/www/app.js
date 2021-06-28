import { setUpGraph, renderGraph } from "./graph.js";
import {
  setUpAnimation,
  renderInfrastructure,
  renderPatientPosition,
  maxQueueLength
} from "./animation.js";

let pooled, numberPatientTypes;

setUpAnimation();
setUpGraph();

Shiny.addCustomMessageHandler("update-animation", function (data) {
  pooled = document.getElementById("pooled").checked;
  numberPatientTypes = document.getElementById("patientTypes").value;

  if (pooled) {
    renderInfrastructure(numberPatientTypes, true);

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
  } else {
    renderInfrastructure(numberPatientTypes, false);

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
  }

  console.log(data);
  renderPatientPosition(data, numberPatientTypes, pooled);
});

Shiny.addCustomMessageHandler("update-graph", function (data) {
  renderGraph(data);
});
