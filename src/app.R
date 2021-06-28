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
                     "Number of patient types:",
                     value = 2,
                     min = 1,
                     max = 3),
        checkboxInput("pooled",
                      "Pool patients/queues",
                      value = FALSE),
        checkboxInput("variability",
                      "Use variable rates",
                      value = FALSE),
        h4("Green Patients"),
        sliderInput(
            "arrivalRateX",
            "Arrival rate:",
            min = 1,
            max = 20,
            value = 9
        ),
        sliderInput(
            "serviceRateX",
            "Service rate:",
            min = 1,
            max = 20,
            value = 11
        ),
        h4("Blue Patients"),
        sliderInput(
            "arrivalRateY",
            "Arrival rate:",
            min = 1,
            max = 20,
            value = 9
        ),
        sliderInput(
            "serviceRateY",
            "Service rate:",
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
            width = 2),
        mainPanel(
            div(class="top", div(class="animation"), div(class="statusinfo", "content needed")),
            div(class="bottom", div(class="graph")),
            width = 9
        ))
}

ui <- navbarPage(
    "Queueing Education Tool",
    tags$head(tags$script(src = "https://d3js.org/d3.v5.min.js"),
              tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")),
    selected = "App",
    tabPanel("App", app()),
    tabPanel("About", includeMarkdown("about.md")),
    tags$script(type = "module", src = "app.js"),
    tags$script(type = "module", src = "graph.js"),
    tags$script(type = "module", src = "animation.js")
)

#############################
### END UI / START SERVER ###
#############################

server <- function(input, output, session) {
    # constants
    queueMax <- 10
    arrivalMax <- 10000
    fastRate <- 10000
    mediumRate <- 30000
    slowRate <- 50000
    
    # initial variables
    clock <- as.double(0)
    arrivalCount <- 0
    scheduledCount <- 0
    pooled <- isolate(input$pooled)
    variability <- isolate(input$variability)
    numberPatientTypes <- isolate(input$patientTypes)
    progressionRate <- mediumRate
    
    arrivalRate <- c(X = isolate(input$arrivalRateX), Y = isolate(input$arrivalRateY)) # extend by Z
    serviceRate <- c(X = isolate(input$serviceRateX), Y = isolate(input$serviceRateY)) # extend by Z
    
    # set up waiting queue and future event list (FEL)
    waitingQueue <- data.frame(id = integer(), type = integer()) # was character before
    futureEventList <-
        data.frame(time = double(),
                   event = character(),
                   type = integer()) # was character before
    
    # set up idle doctors
    doctorCare <- c(X = NA, Y = NA) # extend by Z
    
    # statistics stuff
    statistics <- 
        data.frame(
            avgWaitingTimeX = double(),
            avgWaitingTimeY = double(),
            avgPatientsInQueue = double()
        )
    
    patientStats <-
        data.frame(
            id = integer(),
            type = integer(),
            arrivalTime = double(),
            startMedical = double(),
            endMedical = double()
        )
    
    systemStats <-
        data.frame(
            time = double(),
            queuedPatientsX = integer(),
            queuedPatientsY = integer()
        )
    
    logPatient <- function(id, type) {
        patient <- data.frame(
            id = as.integer(id),
            type = type,
            arrivalTime = as.double(NA),
            startMedical = as.double(NA),
            endMedical = as.double(NA))
        patientStats <<- rbind(patientStats, patient)
        patientStats <<- tail(patientStats, 80) # privacy regulations
    }
    
    logPatientTime <- function(id, col, time) {
        patientStats[patientStats$id == id, col] <<- time
    }
    
    calcAvgWaitingTime <- function(patientType = "") { 
        relevantData <- na.omit(patientStats)
        relevantData <- tail(relevantData, 20) # last 20 completed patients
        if (patientType != "") {
            relevantData <- subset(relevantData, type == patientType)
        }
        if (nrow(relevantData) > 0) {
            relevantTime <- relevantData$startMedical - relevantData$arrivalTime
            mean(relevantTime)
        } else {
            0
        }
        
    }
    
    calcQueueLength <- function(patientType) {
        nrow(subset(waitingQueue, type == patientType))
        
        # if (pooled) {
        #     nrow(waitingQueue)
        # } else {
        #     nrow(subset(waitingQueue, type == patientType))
        # }
    }
    
    logSystem <- function() {
        currentSystem <- data.frame(
            time = clock,
            queuedPatientsX = calcQueueLength(1),
            queuedPatientsY = calcQueueLength(2)
        )
        systemStats <<- rbind(systemStats, currentSystem)
        systemStats <<- tail(systemStats, 80)
    }
    
    calcAvgPatientsInQueue <- function() {
        queuedPatients <- systemStats$queuedPatientsX + systemStats$queuedPatientsY
        queuedPatients <- tail(queuedPatients, 20)
        mean(queuedPatients)
    }
    
    extendStatistics <- function() {
        newRow <- data.frame(
            avgWaitingTimeX = calcAvgWaitingTime(1),
            avgWaitingTimeY = calcAvgWaitingTime(2),
            avgPatientsInQueue = calcAvgPatientsInQueue()
        )
        statistics <<- rbind(statistics, newRow)
        statistics <<- tail(statistics, 80)
    }
    
    
    ####################################
    ## START FUNCTIONS FOR SIMULATION ##
    ####################################
    
    # generate random number from exp dist and truncate
    genInterTime <- function(event, type) {
        if (variability) {
            
            if (event == "arrival") {
                rate <-
                    arrivalRate[type] # can be seen as avg patients arriving per hour
                min <- 0
            } else if (event == "departure") {
                rate <- serviceRate[type]
                min <- 0 # 0.1
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
            
        } else {
            
            if (event == "arrival") {
                rate <-
                    arrivalRate[type] # can be seen as avg patients arriving per hour
            } else if (event == "departure") {
                rate <- serviceRate[type]
            } else {
                print("ERROR: event was neither arrival nor departure.")
            }
            
            1 / rate
            
        }
    }
    
    # add a new event to the Future Event List
    addEvent <- function(event, type) {
        newEvent <-
            data.frame(
                time = as.double(clock + genInterTime(event, type)),
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
            any(waitingQueue$type == type)
        }
    }
    
    # calcQueueMax <- function() {
    #     if (pooled) {
    #         2 * queueMax
    #     } else {
    #         queueMax
    #     }
    # }
    
    # patient arrival
    modelArrival <- function(type, currentlyPooled) {
        if (currentlyPooled) {
            if (nrow(waitingQueue) < 2 * queueMax) {
                arrivalCount <<- arrivalCount + 1
                enqueue(type)
                logPatient(arrivalCount, type)
                logPatientTime(arrivalCount, "arrivalTime", clock)
            }
        } else {
            if (calcQueueLength(type) < queueMax) {
                arrivalCount <<- arrivalCount + 1
                enqueue(type)
                logPatient(arrivalCount, type)
                logPatientTime(arrivalCount, "arrivalTime", clock)
            }
        }
        
        if (scheduledCount < arrivalMax) {
            addEvent("arrival", type) # schedule next arrival
            scheduledCount <<- scheduledCount + 1
        }
    }
    
    # patient departure
    modelDeparture <- function(type) {
        logPatientTime(doctorCare[type], "endMedical", clock)
        logSystem()
        extendStatistics()
        
        data <- toJSON(statistics)
        session$sendCustomMessage("update-graph", data)
        
        doctorCare[type] <<- NA
    }
    
    ##################################
    ## END FUNCTIONS FOR SIMULATION ##
    ##################################
    
    ## ---------------------------- ##
    
    ##########################
    ## START SIMULATION RUN ##
    ##########################
    
    # simulation initialization
    addEvent("arrival", 1) # 2nd argument was "X" before
    addEvent("arrival", 2) # "Y"
    scheduledCount <- 2
    
    # simulation main loop
    observe({
        # invalidateLater(timeUntilNextEvent * progressionRate)
        
        # A Phase
        clock <<- as.numeric(futureEventList[1, 1])
        currentlyPooled <- pooled
        
        while (futureEventList[1, 1] == clock) { # some bug here where the FEL can be empty?
            event <- futureEventList[1,]
            futureEventList <<- futureEventList[-c(1), ]
            print(paste0("Time: ", clock))
            
            # B Phase
            if (event[1, ]$event == "arrival") {
                modelArrival(event[1, ]$type, currentlyPooled)
            } else if (event[1, ]$event == "departure") {
                modelDeparture(event[1, ]$type)
            } else {
                print("ERROR: undefined event.")
            }
        }
        
        
        # C Phase
        if (is.na(doctorCare['X']) &&
            isPatientWaiting(1, currentlyPooled)) {
            dequeue(1, currentlyPooled) # "X" before
            addEvent("departure", 1) # schedule next departure
        }
        if (is.na(doctorCare['Y']) &&
            isPatientWaiting(2, currentlyPooled)) {
            dequeue(2, currentlyPooled) # "Y" before
            addEvent("departure", 2) # schedule next departure
        }
        
        
        timeUntilNextEvent <<- futureEventList[1, 1] - clock
        print(paste0("Until next: ", timeUntilNextEvent))
        if (input$play) {
            timing <- timeUntilNextEvent * progressionRate
            # print(paste0("Timing: ", progressionRate))
            invalidateLater(timing)
        } else {
            print(patientStats)
        }
        
        # send state of system to JS
        gettingMedical <-
            data.frame(id = as.integer(c(doctorCare['X'], doctorCare['Y'])), type = as.integer(c(-1, -2)))
        gettingMedical <- na.omit(gettingMedical)
        data <- rbind(gettingMedical, waitingQueue)
        data <- toJSON(data)
        session$sendCustomMessage("update-animation", data)
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
        variability <<- input$variability
    })
}

##################
### END SERVER ###
##################


shinyApp(ui, server)