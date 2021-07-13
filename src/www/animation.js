// constants for animation at top
const animationHeight = 350; //320;
const animationWidth = 850;
const animationMargin = { top: 20, right: 20, bottom: 25, left: 30 };
const animationInnerHeight =
  animationHeight - animationMargin.top - animationMargin.bottom;
const animationInnerWidth =
  animationWidth - animationMargin.left - animationMargin.right;
const queueSpacing = animationInnerWidth / 18; //44;
const patientDiameter = (8 / 11) * queueSpacing;
const patientRadius = patientDiameter / 2; //16;
const officeWidth = queueSpacing;
const officeHeight = queueSpacing * 2;
export const maxQueueLength = 10;

// scales
const colorScale = d3
  .scaleOrdinal()
  .domain([1, 2, -1, -2])
  .range(["green", "steelblue"]);

export function renderInfrastructure(selection, numberQueues, pooled) {
  const xPosition = (d, i) => {
    if (pooled) {
      return ((numberQueues - 1 - i) * queueSpacing) / numberQueues;
    } else {
      return 0;
    }
  };

  const yPosition = (d, i) => {
    if (pooled) {
      return animationInnerHeight / 2 + i * queueSpacing;
    } else {
      return ((i + 1) * animationInnerHeight) / numberQueues;
    }
  };

  const mirror = (d, i) => {
    if (pooled && i === 0) {
      return -1;
    } else {
      return 1;
    }
  };

  // START doctor offices
  let gSelection = selection.select(".doctor-offices");

  const offices = gSelection.selectAll("g.office").data(d3.range(numberQueues));
  const officesEnter = offices
    .enter()
    .append("g")
    .attr("class", "office")
    .attr(
      "transform",
      (d, i) =>
        `translate(${(maxQueueLength + 2) * queueSpacing}, ${
          ((i + 1) * animationInnerHeight) / numberQueues - officeHeight
        })`
    );
  officesEnter
    .merge(offices)
    .transition()
    .attr(
      "transform",
      (d, i) =>
        `translate(${(maxQueueLength + 2) * queueSpacing}, ${
          ((i + 1) * animationInnerHeight) / numberQueues - officeHeight
        })`
    );
  offices.exit().remove();
  officesEnter
    .append("rect")
    .attr("width", officeWidth)
    .attr("height", officeHeight)
    .attr("fill", "none")
    .attr("stroke", "black");

  officesEnter
    .append("g")
    .attr("transform", `translate(${6/44 * queueSpacing}, ${4/44 * queueSpacing}) scale(${1/44 * queueSpacing})`)
    .append("image").attr("xlink:href", "doctor.svg");

  // START waiting lines
  gSelection = selection.select(".waiting-lines");

  const queues = gSelection.selectAll("g").data(d3.range(numberQueues));
  const queuesEnter = queues
    .enter()
    .append("g")
    .attr("transform", (d, i) => `translate(0, ${yPosition(d, i)})`);
  queuesEnter
    .merge(queues)
    .transition()
    .attr(
      "transform",
      (d, i) => `translate(${xPosition(d, i)}, ${yPosition(d, i)})`
    );
  queues.exit().remove();
  queuesEnter
    .append("line")
    .attr("x1", 0)
    .attr("y1", 0)
    .attr("x2", maxQueueLength * queueSpacing)
    .attr("y2", 0)
    .attr("stroke", "black");

  const ticks = queuesEnter.selectAll("line .tick").data(d3.range(11));
  const ticksEnter = ticks
    .enter()
    .append("line")
    .attr("class", "tick")
    .attr("x1", (d, i) => i * queueSpacing)
    .attr("y1", 0)
    .attr("x2", (d, i) => i * queueSpacing)
    .attr("stroke", "black")
    .attr("y2", -10);
}

export function setUpAnimation(selection) {
  //append svg to designated element
  let svg = selection //.animation div created in Shiny
    .append("svg")
    .attr("class", "animation-svg")
    .attr("preserveAspectRatio", "xMinYMin meet")
    .attr("viewBox", `0 0 ${animationWidth} ${animationHeight}`);

  //svg.append("image").attr("xlink:href", "animation_background.svg");

  const hospital = svg
    .append("g")
    .attr("class", "hospital")
    .attr(
      "transform",
      `translate(${animationMargin.left}, ${animationMargin.top})`
    );

  const infrastructure = hospital.append("g").attr("class", "infrastructure");

  // waiting lines
  const waitingLines = infrastructure
    .append("g")
    .attr("class", "waiting-lines"); //waitingAreaG.call(renderWaitingArea); //renderWaitingArea([1, 2]);

  // exit door
  const exitDoor = infrastructure.append("g").attr("class", "exit-door");
  exitDoor
    .append("rect")
    .attr("x", animationInnerWidth - officeWidth)
    .attr("y", animationInnerHeight - officeHeight)
    .attr("width", officeWidth)
    .attr("height", officeHeight)
    .attr("fill", "black");

  // doctor offices
  const doctorOffices = infrastructure
    .append("g")
    .attr("class", "doctor-offices");

  hospital.append("g").attr("class", "patients");
}

function renderPatientEmoji(selection) {
  // Patient appearance
  selection
    .append("circle")
    .attr("cx", patientRadius)
    .attr("cy", patientRadius)
    .attr("r", patientRadius)
    .attr("fill", (d) => colorScale(d.type));
  selection
    .append("circle")
    .attr("cx", (10.5 / 16) * patientRadius)
    .attr("cy", (9.5 / 16) * patientRadius)
    .attr("r", (1.5 / 16) * patientRadius)
    .attr("fill", "black");
  selection
    .append("circle")
    .attr("cx", (21.5 / 16) * patientRadius)
    .attr("cy", (9.5 / 16) * patientRadius)
    .attr("r", (1.5 / 16) * patientRadius)
    .attr("fill", "black");
  selection
    .append("rect")
    .attr("x", (6 / 16) * patientRadius)
    .attr("y", (16 / 16) * patientRadius)
    .attr("height", (10 / 16) * patientRadius)
    .attr("width", (20 / 16) * patientRadius)
    .attr("fill", "white");
  selection
    .append("line")
    .attr("x1", 0)
    .attr("y1", (12 / 16) * patientRadius)
    .attr("x2", (6 / 16) * patientRadius)
    .attr("y2", (17 / 16) * patientRadius)
    .attr("stroke-width", (1 / 16) * patientRadius)
    .attr("stroke", "white");
  selection
    .append("line")
    .attr("x1", (2 / 16) * patientRadius)
    .attr("y1", (24 / 16) * patientRadius)
    .attr("x2", (7 / 16) * patientRadius)
    .attr("y2", (23 / 16) * patientRadius)
    .attr("stroke-width", (1 / 16) * patientRadius)
    .attr("stroke", "white");
  selection
    .append("line")
    .attr("x1", (26 / 16) * patientRadius)
    .attr("y1", (17 / 16) * patientRadius)
    .attr("x2", (32 / 16) * patientRadius)
    .attr("y2", (12 / 16) * patientRadius)
    .attr("stroke-width", (1 / 16) * patientRadius)
    .attr("stroke", "white");
  selection
    .append("line")
    .attr("x1", (25 / 16) * patientRadius)
    .attr("y1", (23 / 16) * patientRadius)
    .attr("x2", (30 / 16) * patientRadius)
    .attr("y2", (24 / 16) * patientRadius)
    .attr("stroke-width", (1 / 16) * patientRadius)
    .attr("stroke", "white");
  selection
    .append("text")
    .text((d) => d.id)
    .attr("y", 60);
}

export function renderPatientPosition(selection, patients, numberPatientTypes, pooled) {
  let svg = selection.select(".patients");

  const xPosition = (d, i) => {
    let position =
      (9 - d.pos) * queueSpacing + (queueSpacing - patientDiameter) / 2;
    if (pooled && d.pos > -3) {
      position =
        position +
        ((numberPatientTypes - 1 - d.queue) * queueSpacing) /
          numberPatientTypes;
    }
    return position;
  };

  const yPosition = (d, i) => {
    if (pooled && d.pos > -3) {
      return (
        animationInnerHeight / 2 +
        d.queue * queueSpacing -
        queueSpacing +
        (queueSpacing - patientDiameter) / 2
      );
    } else {
      return (
        (d.queue * animationInnerHeight) / numberPatientTypes -
        queueSpacing +
        (queueSpacing - patientDiameter) / 2
      );
    }
  };

  const groups = svg.selectAll("g").data(patients, (d) => d.id);
  const groupsEnter = groups
    .enter()
    .append("g")
    .attr("transform", (d, i) => `translate(-50, ${yPosition(d, i)})`);
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
    .attr(
      "transform",
      `translate(${
        animationInnerWidth - officeWidth + (officeWidth - patientDiameter) / 2
      }, ${
        animationInnerHeight - officeWidth + (officeWidth - patientDiameter) / 2
      })`
    )
    .remove();

  groupsEnter.call(renderPatientEmoji);

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
