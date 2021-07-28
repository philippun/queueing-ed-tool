# queueing-ed-tool
An educational tool about the effects of pooling on queueing systems for healthcare management.

<pre>
src/  
 ├── www/  
      ├── animation.js  
      ├── animation_background.svg  
      ├── app.js  
      ├── doctor.svg  
      ├── graph.js  
      ├── styles.css  
      └── wall.svg  
 ├── about.md  
 └── app.R  
README.md  
</pre>


**src/** Directory with the source code.

**www/** Directory containing the files that eventually end up in the users browser

**animation.js** JavaScript file contating the D3 animation.

**animation2.js** A possible new version of the JavaScript D3 animation in an idempotent style. Not in use yet.

**animation_background.svg** An SVG version of the animation background unpooled system. Not used in the application anymore.

**app.js** The main JavaScript file that is imported into the Shiny application and that handles all other JS files.

**doctor.svg** An SVG version of the doctor. Not used in the application.

**graph.js** Old JavaScript file of the graphs. Deprecated.

**graph2.js** JavaScript file containing the D3 graphs. 

**styles.css** The one single styles file that has all customs styles.

**wall.svg** An SVG of a simple wall. Not used in the application.

**about.md** A markdown file that is incorporated in the running app as a tab containing about information.

**app.R** The Shiny application containing the interface layout and simulation model.
