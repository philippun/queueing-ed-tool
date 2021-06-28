// constants for graph at bottom
const graphHeight = 260;
const graphWidth = 1000;
const graphMargin = { top: 20, right: 30, bottom: 25, left: 30 };
const graphInnerWidth = graphWidth - graphMargin.left - graphMargin.right;
const graphInnerHeight = graphHeight - graphMargin.top - graphMargin.bottom;

// x and y values for graph
const xValue = (d, i) => i;
const yValue = (d) => d.avgPatientsInQueue;
const yValueWaitingX = (d) => d.avgWaitingTimeX;
const yValueWaitingY = (d) => d.avgWaitingTimeY;

const xScaleBand = d3
  .scaleBand()
  .domain(d3.range(0, 99))
  .range([0, graphInnerWidth])
  .padding(0.1);

const xScalePoint = d3
  .scalePoint()
  .domain(d3.range(0, 99))
  .range([0, graphInnerWidth])
  .padding(0.5);

const yScale = d3.scaleLinear().domain([0, 22]).range([graphInnerHeight, 0]);

const yScaleWaiting = d3
  .scaleLinear()
  .domain([0, 1])
  .range([graphInnerHeight, 0]);

export function setUpGraph() {
  let svg = d3
    .select(".graph")
    .append("svg")
    .attr("preserveAspectRatio", "xMinYMin meet")
    .attr("viewBox", `0 0 ${graphWidth} ${graphHeight}`);

  let g = svg
    .append("g")
    .attr("class", "graph-group")
    .attr("transform", `translate(${graphMargin.left},${graphMargin.top})`);

  let g2 = svg
    .append("g")
    .attr("class", "waiting-group")
    .attr("transform", `translate(${graphMargin.left},${graphMargin.top})`);

  g.append("g").call(d3.axisLeft(yScale));

  g.append("g")
    .attr("transform", `translate(${graphInnerWidth}, 0)`)
    .call(d3.axisRight(yScaleWaiting));

  svg
    .append("g")
    .call(d3.axisBottom(xScaleBand))
    .attr(
      "transform",
      `translate(${graphMargin.left}, ${graphMargin.top + graphInnerHeight})`
    )
    .attr("class", "bottomAxis")
    .selectAll("text")
    .attr("transform", `translate(${-xScaleBand.step()},15), rotate(-90)`);
}

export function renderGraph(data) {
  let graph = d3.select(".graph-group");

  let avgPatientsInQueue = graph.selectAll("rect").data(data);
  avgPatientsInQueue
    .enter()
    .append("rect")
    .attr("fill", "gray")

    .merge(avgPatientsInQueue)
    .attr("x", (d, i) => xScaleBand(i))
    .attr("width", xScaleBand.bandwidth())
    .attr("y", (d) => yScale(yValue(d)))
    .attr("height", (d) => yScale(0) - yScale(yValue(d)));
  avgPatientsInQueue.exit().remove();

  let waitingGraph = d3.select(".waiting-group");

  // avg waiting time x path
  let avgWaitingTimeXLineGenerator = d3
    .line()
    .x((d, i) => xScalePoint(i))
    .y((d) => yScaleWaiting(yValueWaitingX(d)))
    .curve(d3.curveBasis);

  let avgWaitingTimeX = waitingGraph.selectAll(".waitingX-path").data([data]);
  avgWaitingTimeX
    .enter()
    .append("path")
    .attr("class", "waitingX-path")
    .attr("stroke", "green")
    .attr("stroke-width", 2)
    .attr("fill", "none")
    .merge(avgWaitingTimeX)
    .attr("d", avgWaitingTimeXLineGenerator(data));

  // avg waiting time y path
  let avgWaitingTimeYLineGenerator = d3
    .line()
    .x((d, i) => xScalePoint(i))
    .y((d) => yScaleWaiting(yValueWaitingY(d)))
    .curve(d3.curveBasis);

  let avgWaitingTimeY = waitingGraph.selectAll(".waitingY-path").data([data]);
  avgWaitingTimeY
    .enter()
    .append("path")
    .attr("class", "waitingY-path")
    .attr("stroke", "steelblue")
    .attr("stroke-width", 2)
    .attr("fill", "none")
    .merge(avgWaitingTimeY)
    .attr("d", avgWaitingTimeYLineGenerator(data));
}
