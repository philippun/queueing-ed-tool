function setUpAnimation() {
    const height = 320;
    const width = 850;

    //append svg to designated element
    let svg = d3.select(".animation") //.animation created in Shiny
        .append("svg")
          .attr("preserveAspectRatio", "xMinYMin meet")
          .attr("viewBox", `0 0 ${width} ${height}`);

    svg.append("image")
        .attr("xlink:href","animation_background.svg")
}

function renderAnimation(patients) {
    const xPosition = (d, i) => d.hasOwnProperty('pos') ? (9 - d.pos) * 44 + 62 : 9;

    const yPosition = (d, i) => {
        if (d.type === "X" || d.type === "atX") {
            return 106 + 16;
        } else if (d.type === "Y" || d.type === "atY") {
            return 106 + 16 + 144;
        }
    }

    const colorScale = d3.scaleOrdinal()
        .domain(['X', 'Y', 'atX', 'atY'])
        .range(['green', 'blue']);

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
        .remove();
}

setUpAnimation();
//renderAnimation();

Shiny.addCustomMessageHandler('update-waiting', function(data) {
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
