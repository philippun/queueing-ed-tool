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

function renderAnimation(patients) {
    const xPosition = (d, i) => (9 - i) * 44 + 62;

    let svg = d3.select(".animation svg")

    /*const makePatient = type => ({
        type,
        id: Math.random()
    });
    let patients = d3.range(5)
        .map(() => makePatient('patient'));*/

    /*const groups = svg.selectAll('g')
        .data(patients);
    const groupsEnter = groups
        .enter().append('g');
    groupsEnter.merge(groups)
        .attr('transform', (d, i) =>
        `translate(${i * 180 + 100},${height / 2})`
        );
        .transition()
          .attr('x', xPosition)
          .attr('y', 106 + 16);
      groups.exit()
        .transition().duration(500)
        .attr('x', 500)
        .remove();

    groupsEnter.append('circle')
      .merge(groups.select('circle'))
          .attr('r', 16)
          .attr('fill', 'green')
          .attr('cx', xPosition)

    groupsEnter.append('text')
      .merge(groups.select('text'))
        .text(d => d.id)*/

    const circles = svg.selectAll('circle')
        .data(patients, d => d.id);
      circles
        .enter().append('circle')
          .attr('cy', 106 + 16)
          .attr('r', 16 * Math.random() + 5)
          .attr('fill', 'green')
        .merge(circles)
        .transition()
          .attr('cx', xPosition)
      circles.exit()
        .transition().duration(500)
        .attr('cx', 500)
        .remove();
}

setUpAnimation();
//renderAnimation();

Shiny.addCustomMessageHandler('update-waiting', function(data) {
    console.log(data);
    renderAnimation(data);
    });
