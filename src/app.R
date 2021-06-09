library(shiny)
library(jsonlite)

################
### START UI ###
################

settings <- function() {
    tabPanel(
        "Settings",
        h3("Hospital"),
        numericInput("patientTypes", 
                     "Types of patients:", 
                     value = 2, 
                     min = 2, 
                     max = 2, 
                     step = 1),
        checkboxInput("pooled",
                      "Pool patients/queues",
                      value = TRUE),
        h3("Patients"),
        sliderInput(
            "arrivalRateX",
            "Arrival rate patient type 1:",
            min = 1,
            max = 20,
            value = 9
        ),
        sliderInput(
            "serviceRateX",
            "Service rate patient type 1:",
            min = 1,
            max = 20,
            value = 11
        ),
        sliderInput(
            "arrivalRateY",
            "Arrival rate patient type 2:",
            min = 1,
            max = 20,
            value = 9
        ),
        sliderInput(
            "serviceRateY",
            "Service rate patient type 2:",
            min = 1,
            max = 20,
            value = 11
        )
    )
}

scenarios <- function() {
    tabPanel(
        "Scenarios",
        h3("...")
        )
}

app <- function() {
    sidebarLayout(
        sidebarPanel(
            checkboxInput("play",
                          "Play/Pause",
                          value = TRUE),
            tabsetPanel(settings(),
                        scenarios()),
            width = 3),
        mainPanel(
            div(class="animation")
        ))
}

ui <- navbarPage(
    "Queueing Education Tool",
    tags$head(tags$script(src = "https://d3js.org/d3.v5.min.js"),
              tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")),
    selected = "App",
    tabPanel("App", app()),
    tabPanel("About", includeMarkdown("about.md")),
    tags$script(src = "app.js")
)

#############################
### END UI / START SERVER ###
#############################

server <- function(input, output, session) {
    # constants
    arrivalMax <- 10000
    fastRate <- 10000
    mediumRate <- 30000
    slowRate <- 50000
    
    # initial variables
    clock <- as.double(0)
    arrivalCount <- 0
    scheduledCount <- 0
    pooled <- TRUE
    progressionRate <- mediumRate
    
    arrivalRate <- c(X = 9, Y = 9)
    serviceRate <- c(X = 11, Y = 11)
    
    # set up waiting queue and future event list (FEL)
    waitingQueue <- data.frame(id = integer(), type = character())
    futureEventList <-
        data.frame(time = double(),
                   event = character(),
                   type = character())
    
    # set up idle doctors
    doctorCare <- c(X = NA, Y = NA)
    
    # statistics stuff
    patientStats <-
        data.frame(
            id = integer(),
            type = character(),
            arrivalTime = double(),
            startMedical = double(),
            endMedical = double()
        )
    
    logPatient <- function(id, type) {
        patient <- data.frame(
            id = as.integer(id),
            type = type,
            arrivalTime = as.double(NA),
            startMedical = as.double(NA),
            endMedical = as.double(NA))
        patientStats <<- rbind(patientStats, patient)
    }
    
    logPatientTime <- function(id, col, time) {
        patientStats[patientStats$id == id, col] <<- time
    }
    
    calcAvgWaiting <- function() {
        relevantData <- na.omit(patientStats)
        relevantData <- tail(relevantData, 20)
        relevantTime <- relevantData$startMedical - relevantData$arrivalTime
        mean(relevantTime)
    }
    
    
    ####################################
    ## START FUNCTIONS FOR SIMULATION ##
    ####################################
    
    # generate random number from exp dist and truncate
    genRand <- function(event, type) {
        if (event == "arrival") {
            rate <-
                arrivalRate[type] # can be seen as avg patients arriving per hour
            min <- 0
        } else if (event == "departure") {
            rate <- serviceRate[type]
            min <- 0.1
        } else {
            print("ERROR: event was neither arrival nor departure.")
        }
        
        trunc <- 4
        num <- rexp(1, rate = rate)
        if (num > (trunc * 1 / rate)) {
            (trunc * 1 / rate) + min
        } else {
            num + min
        }
    }
    
    # add a new event to the Future Event List
    addEvent <- function(event, type) {
        newEvent <-
            data.frame(
                time = as.double(clock + genRand(event, type)),
                event = c(event),
                type = c(type)
            )
        futureEventList <<- rbind(futureEventList, newEvent)
        futureEventList <<-
            futureEventList[order(futureEventList$time),]
    }
    
    # enqueues a new patient arrival
    enqueue <- function(type) {
        newPatient <- c(arrivalCount, type)
        newPatient <-
            data.frame(matrix(newPatient, ncol = 2, nrow = 1))
        colnames(newPatient) <- c('id', 'type')
        waitingQueue <<- rbind(waitingQueue, newPatient)
    }
    
    # dequeues a patient
    # considers if queues are currently pooled or not
    dequeue <- function(type, currentlyPooled) {
        if (currentlyPooled) {
            # print(paste0("Took in patient of type ", waitingQueue[1,2]))
            patientId <- waitingQueue[1, 1]
            doctorCare[type] <<- patientId
            waitingQueue <<- waitingQueue[-c(1), ]
            logPatientTime(patientId, "startMedical", clock)
        } else {
            for (i in 1:nrow(waitingQueue)) {
                if (waitingQueue[i, "type"] == type) {
                    # print(paste0("Took in patient of type ", waitingQueue[i,2]))
                    patientId <- waitingQueue[i, 1]
                    doctorCare[type] <<- patientId
                    waitingQueue <<- waitingQueue[-c(i), ]
                    logPatientTime(patientId, "startMedical", clock)
                    break
                }
            }
        }
    }
    
    # check if a patient is waiting
    # considers if queues are currently pooled or not
    isPatientWaiting <- function(type, currentlyPooled) {
        if (currentlyPooled) {
            nrow(waitingQueue) > 0
        } else {
            any(waitingQueue == type)
        }
    }
    
    # patient arrival
    modelArrival <- function(type) {
        arrivalCount <<- arrivalCount + 1
        enqueue(type)
        logPatient(arrivalCount, type)
        logPatientTime(arrivalCount, "arrivalTime", clock)
        
        if (scheduledCount < arrivalMax) {
            addEvent("arrival", type) # schedule next arrival
            scheduledCount <<- scheduledCount + 1
        }
    }
    
    # patient departure
    modelDeparture <- function(type) {
        logPatientTime(doctorCare[type], "endMedical", clock)
        doctorCare[type] <<- NA
        print(paste0("Avg waiting time: ", calcAvgWaiting()))
    }
    
    ##################################
    ## END FUNCTIONS FOR SIMULATION ##
    ##################################
    
    ## ---------------------------- ##
    
    ##########################
    ## START SIMULATION RUN ##
    ##########################
    
    # simulation initialization
    addEvent("arrival", "X")
    addEvent("arrival", "Y")
    scheduledCount <- 2
    
    # simulation main loop
    observe({
        # invalidateLater(timeUntilNextEvent * progressionRate)
        
        # A Phase
        event <- futureEventList[1,]
        futureEventList <<- futureEventList[-c(1), ]
        clock <<- as.numeric(event[1, 1])
        print(paste0("Time: ", clock))
        
        data <- toJSON(waitingQueue)
        session$sendCustomMessage("update-waiting", data)
        
        # B Phase
        if (event[1, ]$event == "arrival") {
            modelArrival(event[1, ]$type)
        } else if (event[1, ]$event == "departure") {
            modelDeparture(event[1, ]$type)
        } else {
            print("ERROR: undefined event.")
        }
        
        # C Phase
        currentlyPooled <- pooled
        if (is.na(doctorCare['X']) &&
            isPatientWaiting("X", currentlyPooled)) {
            dequeue("X", currentlyPooled)
            addEvent("departure", "X") # schedule next departure
        }
        if (is.na(doctorCare['Y']) &&
            isPatientWaiting("Y", currentlyPooled)) {
            dequeue("Y", currentlyPooled)
            addEvent("departure", "Y") # schedule next departure
        }
        
        
        timeUntilNextEvent <<- futureEventList[1, 1] - clock
        print(paste0("Until next: ", timeUntilNextEvent))
        if (input$play) {
            invalidateLater(timeUntilNextEvent * progressionRate)
        } else {
            print(patientStats)
        }
    })
    
    ########################
    ## END SIMULATION RUN ##
    ########################
    
    
    observe({
        arrivalRate['X'] <<- input$arrivalRateX
        arrivalRate['Y'] <<- input$arrivalRateY
        serviceRate['X'] <<- input$serviceRateX
        serviceRate['Y'] <<- input$serviceRateY
        pooled <<- input$pooled
    })
}

##################
### END SERVER ###
##################


shinyApp(ui, server)