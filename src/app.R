library(shiny)

settings <- function() {
    tabPanel(
        "Settings",
        h3("Patients"),
        sliderInput("arrivalRate",
                    "Arrival rate:",
                    min = 1,
                    max = 10,
                    value = 5),
        h3("Hospitals"),
        checkboxInput("pooled",
                      "Pool queues",
                      value = FALSE),
        sliderInput("serviceRate",
                    "Service rate:",
                    min = 1,
                    max = 10,
                    value = 5)
    )
}

scenarios <- function() {
    tabPanel(
        "Scenarios"
    )
}

app <- function() {
    sidebarLayout(
        sidebarPanel(
            tabsetPanel(
                settings(),
                scenarios()
            ),
            width = 3
        ),
        mainPanel()
    )
}

ui <- navbarPage(
    "Queueing Education Tool",
    selected = "App",
    tabPanel("App", app()),
    tabPanel("About", includeMarkdown("about.md"))
)

server <- function(input, output, session) {
  
}

shinyApp(ui, server)