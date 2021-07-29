# About page
### Information and FAQ

This page provides some context and information about this application.

## 1. Why?
### In which context was this application created and who created it?
This application was created as part of a Bachelor project in *Industrial Engineering & Management* at the University of Twente (Enschede, The Netherlands). It was created mostly by me, Philipp Ungrund, but with a lot of help and inspiration from some study colleagues and my supervisors. For feedback or specific questions about this tool that are not answered here you can contact me by [mail](philippungrund@icloud.com). 

### What was the motivation for this application?
The motivation for this application comes from the practical experience with consulting healthcare professionals on logistical performance improvements. The idea was to support the process of teaching and explaining them certain concepts from operations management and research in a visual and intuitive way. Because of this, the application can be seen as an educational tool.

### What were the objectives to the development of this educaitonal tool?
There were several objectives to the creation of this educational tool. First of all, it focuses on teaching the effects of pooling independent queueing systems and whether pooling is beneficial or not. For this it makes use of queueing theory. Then, the tool was supposed to be accessible in a web environment to achieve high flexibility in the teaching process. And of course, the scope of a 10 week Bachelor project was an important objective.

## 2. How? 
### How was this tool conceptualized?
The tool was conceptualized with the help of a modeling framework for simulation-based serious games. The specific framework was developed by van der Zee et al. (2012). It makes use of five iterable activities: 
<ol>
<li>Understanding the learning environment</li>
<li>Determine objectives</li>
<li>Identify the model outputs</li>
<li>Identify the model inputs</li>
<li>Determine model content</li>
</ol>
For more details see *van der Zee et al.* (2012).

### How and with the help of what was the tool implemented?
The tool is based on an implementation with *R Shiny*, which is a web-framework for the general purpose programming language R. The simulation model and the general interface was implemented in this way. The visualizations and animations were created with JavaScript and the library *D3* that was developed specifically for data-driven visualizations. For details please see the [code repository](https://github.com/philippun/queueing-ed-tool).

## 3. What?
### What does the interface provide?
The interface provides the input settings for the parameters of the queueing systems in the sidebar on the left. There are options to change the arrival and service rates of two types of patients (green and blue). Predefined scenarios can be used to set these all at once to showcase a specific situation. The outputs show two layouts of the underlying queueing system with one pooled and the other unpooled. Patient arrive to the system and are either served by only one doctor or by two doctors. The arrivals and service rates of each patient type are the same in both layouts. Additionally, there are graphs that give information on the development of the waiting performances. A button at the top of each layout can be clicked to display the theoretical expected waiting time of each system. The interface was heavily inspired by the [Economies of Scale tool](https://tiox.org/stable/#dir) by Gregory Dobson. 

### What does the practical application of the tool look like?
The tool makes use of the involvement of a game operator as specified in the conceptual framework. The game operator is the consultant or teacher, possibly also the player. The operator is supposed to set the tool into different scenarios to bring across a specific learning purpose to e.g. show when pooling is theoretically beneficial. The player is then challenged to assess the two system layout in terms of performance, after which the operator can show the theoretical performance. 
