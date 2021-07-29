export const graph = () => {
  let height = 350;
  let width = 850;
  let data = [];
  let margin;
  let title;

  const my = (selection) => {
    const innerWidth = width - margin.left - margin.right;
    const innerHeight = height - margin.top - margin.bottom;

    const graphG = selection
      .selectAll(".graph-group")
      .data([null])
      .join("g")
      .attr("class", "graph-group")
      .attr("transform", `translate(${margin.left}, ${margin.top})`);

    const patientsQueuedG = graphG
      .selectAll(".queued-patients-group")
      .data([null])
      .join("g")
      .attr("class", "queued-patients-group");

    const xScaleBand = d3
      .scaleBand()
      .domain(d3.range(0, 69))
      .range([0, innerWidth])
      .padding(0.1);

    const xScalePoint = d3
      .scalePoint()
      .domain(d3.range(0, 69))
      .range([0, innerWidth])
      .padding(0.5);

    const yScaleNumberWaiting = d3
      .scaleLinear()
      .domain([0, 22])
      .range([innerHeight, 0]);

    const yScaleWaitingTime = d3
      .scaleLinear()
      .domain([0, 20])
      .range([innerHeight, 0]);

    const xValue = (d, i) => i;
    const yValueQueuedPatients = (d) => d.avgPatientsInQueue;
    const yValueWaitingX = (d) => d.avgWaitingTimeX * 60;
    const yValueWaitingY = (d) => d.avgWaitingTimeY * 60;

    const positionQueuedPatients = (queuedPatients) => {
      queuedPatients
        .attr("x", (d, i) => xScaleBand(i))
        .attr("y", (d, i) => yScaleNumberWaiting(yValueQueuedPatients(d)));
    };

    const queuedPatients = patientsQueuedG
      .selectAll("rect")
      .data(data)
      .join(
        (enter) =>
          enter
            .append("rect")
            .attr("fill", "gray")
            .call(positionQueuedPatients)
            .attr("width", xScaleBand.bandwidth())
            .attr(
              "height",
              (d) =>
                yScaleNumberWaiting(0) -
                yScaleNumberWaiting(yValueQueuedPatients(d))
            ),
        (update) =>
          update
            .call((update) => update.call(positionQueuedPatients))
            .attr("width", xScaleBand.bandwidth())
            .attr(
              "height",
              (d) =>
                yScaleNumberWaiting(0) -
                yScaleNumberWaiting(yValueQueuedPatients(d))
            ),
        (exit) => exit.remove()
      );

    const genWaitingTimeLineX = d3
      .line()
      .x((d, i) => xScalePoint(i))
      .y((d) => yScaleWaitingTime(yValueWaitingX(d)))
      .curve(d3.curveBasis);

    const waitingTimeLineX = graphG.selectAll(".waiting-time-x").data([data]);
    waitingTimeLineX
      .enter()
      .append("path")
      .attr("class", "waiting-time-x")
      .attr("stroke", "green")
      .attr("stroke-width", 2)
      .attr("fill", "none")
      .merge(waitingTimeLineX)
      .attr("d", genWaitingTimeLineX(data));

    const genWaitingTimeLineY = d3
      .line()
      .x((d, i) => xScalePoint(i))
      .y((d) => yScaleWaitingTime(yValueWaitingY(d)))
      .curve(d3.curveBasis);

    const waitingTimeLineY = graphG.selectAll(".waiting-time-y").data([data]);
    waitingTimeLineY
      .enter()
      .append("path")
      .attr("class", "waiting-time-y")
      .attr("stroke", "steelblue")
      .attr("stroke-width", 2)
      .attr("fill", "none")
      .merge(waitingTimeLineY)
      .attr("d", genWaitingTimeLineY(data));

    graphG
      .selectAll(".y-axis-left")
      .data([null])
      .join("g")
      .attr("class", "y-axis-left")
      .call(d3.axisLeft(yScaleNumberWaiting));

    graphG
      .selectAll(".y-axis-left-label")
      .data([null])
      .join("text")
      .attr("class", "y-axis-left-label")
      .attr("y", -30)
      .attr("x", -innerHeight / 2)
      .attr("transform", `rotate(-90)`)
      .attr("text-anchor", "middle")
      .text("Number of Patients");

    graphG
      .selectAll(".y-axis-right")
      .data([null])
      .join("g")
      .attr("class", "y-axis-right")
      .attr("transform", `translate(${innerWidth}, 0)`)
      .call(d3.axisRight(yScaleWaitingTime));

    graphG
      .selectAll(".y-axis-right-label")
      .data([null])
      .join("text")
      .attr("class", "y-axis-right-label")
      .attr('y', innerWidth + 45)
      .attr('x', - innerHeight / 2)
      .attr("transform", `rotate(-90)`)
      .attr("text-anchor", "middle")
      .text("Minutes of Waiting");

    const bottomAxis = graphG
      .selectAll(".x-axis")
      .data([null])
      .join("g")
      .attr("class", "x-axis")
      .attr("transform", `translate(0, ${innerHeight})`)
      .call(
        d3
          .axisBottom(xScaleBand)
          /*.tickValues(
          xScaleBand.domain().filter(function (d, i) {
            return !(i % 4);
          })
        )*/
          .tickSizeOuter(0)
      );

    bottomAxis.selectAll("text").remove();

    const legendLeftG = graphG
      .selectAll(".legend-left")
      .data([null])
      .join("g")
      .attr("class", "legend-left")
      .attr("transform", `translate(${innerWidth / 2 - 200}, 0)`);

    const legendRightG = graphG
      .selectAll(".legend-right")
      .data([null])
      .join("g")
      .attr("class", "legend-right")
      .attr("transform", `translate(${innerWidth / 2}, 0)`);

    legendLeftG
      .selectAll(".legend-queued-patients")
      .data([null])
      .join("text")
      .attr("class", "legend-queued-patients")
      .attr("transform", `translate(${10}, 0)`)
      .attr("fill", "black")
      .text("Average Queued Patients");

    legendLeftG
      .selectAll(".color-queued-patients")
      .data([null])
      .join("circle")
      .attr("class", "color-queued-patients")
      .attr("fill", "gray")
      .attr("r", "5")
      .attr("cx", "0")
      .attr("cy", "-5");

    legendRightG
      .selectAll(".legend-waiting-time")
      .data([null])
      .join("text")
      .attr("class", "legend-waiting-time")
      .attr("transform", `translate(${25}, 0)`)
      .attr("fill", "black")
      .text("Average Waiting Time");

    legendRightG
      .selectAll(".color-wait-time-1")
      .data([null])
      .join("circle")
      .attr("class", "color-wait-time-1")
      .attr("fill", "green")
      .attr("r", "5")
      .attr("cx", "0")
      .attr("cy", "-5");

    legendRightG
      .selectAll(".color-wait-time-2")
      .data([null])
      .join("circle")
      .attr("class", "color-wait-time-2")
      .attr("fill", "steelblue")
      .attr("r", "5")
      .attr("cx", "15")
      .attr("cy", "-5");
  };

  my.height = function (_) {
    return arguments.length ? ((height = +_), my) : height;
  };

  my.width = function (_) {
    return arguments.length ? ((width = +_), my) : width;
  };

  my.data = function (_) {
    return arguments.length ? ((data = _), my) : data;
  };

  my.margin = function (_) {
    return arguments.length ? ((margin = _), my) : margin;
  };

  my.title = function (_) {
    return arguments.length ? ((title = _), my) : title;
  };

  return my;
};
