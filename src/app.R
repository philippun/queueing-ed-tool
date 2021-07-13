library(shiny)
library(jsonlite)

################
### START UI ###
################

settings <- function() {
    tabPanel(
        "Settings",
        h3("Hospital"),
        h4("Green Patients"),
        sliderInput(
            "arrivalRateX",
            "Arrival rate:",
            min = 1,
            max = 50,
            value = 9
        ),
        sliderInput(
            "serviceRateX",
            "Service rate:",
            min = 1,
            max = 60,
            value = 11
        ),
        h4("Blue Patients"),
        sliderInput(
            "arrivalRateY",
            "Arrival rate:",
            min = 1,
            max = 50,
            value = 9
        ),
        sliderInput(
            "serviceRateY",
            "Service rate:",
            min = 1,
            max = 60,
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
            fluidRow(
                column(6, 
                       tags$h3("Unpooled"), 
                       actionButton("showPerformanceUnpooled", "Show mean waiting times"), 
                       verbatimTextOutput("performanceUnpooled", placeholder = T), 
                       div(class="top", div(class="animation-unpooled")), 
                       div(class="bottom", div(class="graph-unpooled"))),
                column(6, 
                       tags$h3("Pooled"), 
                       actionButton("showPerformancePooled", "Show mean waiting times"), 
                       verbatimTextOutput("performancePooled", placeholder = T), 
                       div(class="top", div(class="animation-pooled")), 
                       div(class="bottom", div(class="graph-pooled")))
            ),
            #div(class="top", div(class="animation"), div(class="statusinfo", "content needed")),
            #div(class="bottom", div(class="graph")),
            width = 10
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
    fastRate <- 50000
    mediumRate <- 80000
    slowRate <- 110000
    
    # initial variables
    clock <- as.double(0)
    arrivalCountUnpooled <- 0
    arrivalCountPooled <- 0
    scheduledCount <- 0
    progressionRate <- mediumRate
    
    arrivalRate <- c(X = isolate(input$arrivalRateX), Y = isolate(input$arrivalRateY))
    serviceRate <- c(X = isolate(input$serviceRateX), Y = isolate(input$serviceRateY))
    
    # set up waiting queues and future event list (FEL)
    waitingQueueUnpooled <- data.frame(id = integer(), type = integer())
    waitingQueuePooled <- data.frame(id = integer(), type = integer())
    futureEventList <-
        data.frame(time = double(),
                   event = character(),
                   type = integer(),
                   pooled = logical())
    
    # vector for saving which patient is currently at doctor; set up idle doctors
    doctorCareUnpooled <- c(X = NA, Y = NA)
    doctorCarePooled <- c(X = NA, Y = NA)
    
    
    ## dataframes for holding statistics ##
    # df for holding the overall statistics about unpooled queueing system
    statisticsUnpooled <- 
        data.frame(
            avgWaitingTimeX = double(),
            avgWaitingTimeY = double(),
            avgPatientsInQueue = double()
        )
    
    # df for holding statistics for individual patients in unpooled queueing system
    patientStatsUnpooled <-
        data.frame(
            id = integer(),
            type = integer(),
            arrivalTime = double(),
            startMedical = double(),
            endMedical = double()
        )
    
    # df for holding statistics on patients waiting at specific time in unpooled queueing system
    systemStatsUnpooled <-
        data.frame(
            time = double(),
            queuedPatientsX = integer(),
            queuedPatientsY = integer()
        )
    
    # df for holding the overall statistics about pooled queueing system
    statisticsPooled <- 
        data.frame(
            avgWaitingTimeX = double(),
            avgWaitingTimeY = double(),
            avgPatientsInQueue = double()
        )
    
    # df for holding statistics for individual patients in pooled queueing system
    patientStatsPooled <-
        data.frame(
            id = integer(),
            type = integer(),
            arrivalTime = double(),
            startMedical = double(),
            endMedical = double()
        )
    
    # df for holding statistics on patients waiting at specific time in pooled queueing system
    systemStatsPooled <-
        data.frame(
            time = double(),
            queuedPatientsX = integer(),
            queuedPatientsY = integer()
        )
    
    
    ## functions for calculating statistics ##
    # adds a new patient to the patient statistics
    logPatient <- function(id, type, pooled) {
        patient <- data.frame(
            id = as.integer(id),
            type = type,
            arrivalTime = as.double(NA),
            startMedical = as.double(NA),
            endMedical = as.double(NA))
        if (pooled) {
            patientStatsPooled <<- rbind(patientStatsPooled, patient)
            patientStatsPooled <<- tail(patientStatsPooled, 80) # privacy regulations
        } else {
            patientStatsUnpooled <<- rbind(patientStatsUnpooled, patient)
            patientStatsUnpooled <<- tail(patientStatsUnpooled, 80) # privacy regulations
        }
    }
    
    logPatientTime <- function(id, col, time, pooled) {
        if (pooled) {
            patientStatsPooled[patientStatsPooled$id == id, col] <<- time
        } else {
            patientStatsUnpooled[patientStatsUnpooled$id == id, col] <<- time
        }
        
    }
    
    calcAvgWaitingTime <- function(patientType = "", pooled) { 
        if (pooled) {
            relevantData <- na.omit(patientStatsPooled)
        } else {
            relevantData <- na.omit(patientStatsUnpooled)
        }
        
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
    
    calcQueueLength <- function(patientType, pooled) {
        if (pooled) {
            nrow(waitingQueuePooled)
        } else {
            nrow(subset(waitingQueueUnpooled, type == patientType))
        }
    }
    
    logSystem <- function(pooled) {
        if (pooled) {
            currentSystemPooled <- data.frame(
                time = clock,
                queuedPatientsX = calcQueueLength(1, F),
                queuedPatientsY = calcQueueLength(2, F)
            )
            systemStatsPooled <<- rbind(systemStatsPooled, currentSystemPooled)
            systemStatsPooled <<- tail(systemStatsPooled, 80)
        } else {
            currentSystemUnpooled <- data.frame(
                time = clock,
                queuedPatientsX = calcQueueLength(1, F),
                queuedPatientsY = calcQueueLength(2, F)
            )
            systemStatsUnpooled <<- rbind(systemStatsUnpooled, currentSystemUnpooled)
            systemStatsUnpooled <<- tail(systemStatsUnpooled, 80)
        }
    }
    
    calcAvgPatientsInQueue <- function(pooled) {
        if (pooled) {
            queuedPatients <- systemStatsPooled$queuedPatientsX + systemStatsPooled$queuedPatientsY
            queuedPatients <- tail(queuedPatients, 20)
            mean(queuedPatients)
        } else {
            queuedPatients <- systemStatsUnpooled$queuedPatientsX + systemStatsUnpooled$queuedPatientsY
            queuedPatients <- tail(queuedPatients, 20)
            mean(queuedPatients)
        }
    }
    
    extendStatistics <- function(pooled) {
        newRow <- data.frame(
            avgWaitingTimeX = calcAvgWaitingTime(1, pooled),
            avgWaitingTimeY = calcAvgWaitingTime(2, pooled),
            avgPatientsInQueue = calcAvgPatientsInQueue(pooled)
        )
        
        if (pooled) {
            statisticsPooled <<- rbind(statisticsPooled, newRow)
            statisticsPooled <<- tail(statisticsPooled, 80)
        } else {
            statisticsUnpooled <<- rbind(statisticsUnpooled, newRow)
            statisticsUnpooled <<- tail(statisticsUnpooled, 80)
        }
        
    }
    
    
    ####################################
    ## START FUNCTIONS FOR SIMULATION ##
    ####################################
    
    # generate random number from exp dist and truncated at 4 times mean
    genInterArrivalTime <- function(type) {
        rate <- arrivalRate[type]
        
        trunc <- 4
        num <- rexp(1, rate = rate)
        if (num > (trunc * 1 / rate)) {
            (trunc * 1 / rate)
        } else {
            num
        }
    }
    
    # add a new event to the Future Event List
    addArrivalEvent <- function(type) {
        newEvent <-
            data.frame(
                time = as.double(clock + genInterArrivalTime(type)),
                event = c("arrival"),
                type = c(type),
                pooled = NA
            )
        futureEventList <<- rbind(futureEventList, newEvent)
        futureEventList <<-
            futureEventList[order(futureEventList$time),]
    }
    
    addDepartureEvent <- function(type, pool) {
        newEvent <-
            data.frame(
                time = as.double(clock + 1 / serviceRate[type]),
                event = c("departure"),
                type = c(type),
                pooled = c(pool)
            )
        futureEventList <<- rbind(futureEventList, newEvent)
        futureEventList <<-
            futureEventList[order(futureEventList$time),]
    }
    
    # enqueues a new patient arrival
    enqueue <- function(type, pooled) {
        if (!pooled) {
            newPatient <- c(arrivalCountUnpooled, type)
            newPatient <-
                data.frame(matrix(newPatient, ncol = 2, nrow = 1))
            colnames(newPatient) <- c('id', 'type')
            waitingQueueUnpooled <<- rbind(waitingQueueUnpooled, newPatient)
        } else {
            newPatient <- c(arrivalCountPooled, type)
            newPatient <-
                data.frame(matrix(newPatient, ncol = 2, nrow = 1))
            colnames(newPatient) <- c('id', 'type')
            waitingQueuePooled <<- rbind(waitingQueuePooled, newPatient)
        }
    }
    
    # dequeues a patient
    # considers if queues are currently pooled or not
    dequeue <- function(type, currentlyPooled) {
        if (currentlyPooled) {
            patientId <- waitingQueuePooled[1, 1]
            doctorCarePooled[type] <<- patientId
            waitingQueuePooled <<- waitingQueuePooled[-c(1), ] #changed into Pooled
            logPatientTime(patientId, "startMedical", clock, T)
        } else {
            for (i in 1:nrow(waitingQueueUnpooled)) {
                print("test")
                if (waitingQueueUnpooled[i, "type"] == type) {
                    # print(paste0("Took in patient of type ", waitingQueue[i,2]))
                    patientId <- waitingQueueUnpooled[i, 1]
                    doctorCareUnpooled[type] <<- patientId
                    waitingQueueUnpooled <<- waitingQueueUnpooled[-c(i), ]
                    logPatientTime(patientId, "startMedical", clock, F)
                    break
                }
            }
        }
    }
    
    # check if a patient is waiting
    # considers if queues are currently pooled or not
    isPatientWaiting <- function(type, currentlyPooled) {
        if (currentlyPooled) {
            nrow(waitingQueuePooled) > 0
        } else {
            any(waitingQueueUnpooled$type == type)
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
    modelArrival <- function(type) {
        # if (currentlyPooled) {
        #     if (nrow(waitingQueue) < 2 * queueMax) {
        #         arrivalCount <<- arrivalCount + 1
        #         enqueue(type)
        #         logPatient(arrivalCount, type)
        #         logPatientTime(arrivalCount, "arrivalTime", clock)
        #     }
        # } else {
        #     if (calcQueueLength(type) < queueMax) {
        #         arrivalCount <<- arrivalCount + 1
        #         enqueue(type)
        #         logPatient(arrivalCount, type)
        #         logPatientTime(arrivalCount, "arrivalTime", clock)
        #     }
        # }
        
        if (calcQueueLength(type, F) < queueMax) {
            arrivalCountUnpooled <<- arrivalCountUnpooled + 1
            enqueue(type, F)
            logPatient(arrivalCountUnpooled, type, F)
            logPatientTime(arrivalCountUnpooled, "arrivalTime", clock, F)
        }
        
        if (calcQueueLength(type, T) < 2 * queueMax) {
            arrivalCountPooled <<- arrivalCountPooled + 1
            enqueue(type, T)
            logPatient(arrivalCountPooled, type, T)
            logPatientTime(arrivalCountPooled, "arrivalTime", clock, T)
        }
        
        if (scheduledCount < arrivalMax) {
            addArrivalEvent(type) # schedule next arrival
            scheduledCount <<- scheduledCount + 1
        }
    }
    
    # patient departure
    modelDepartureUnpooled <- function(type) {
        logPatientTime(doctorCareUnpooled[type], "endMedical", clock, F)
        logSystem(F)
        extendStatistics(F)
        
        data <- toJSON(statisticsUnpooled)
        session$sendCustomMessage("update-graph-unpooled", data)
        
        doctorCareUnpooled[type] <<- NA
    }
    
    modelDeparturePooled <- function(type) {
        logPatientTime(doctorCarePooled[type], "endMedical", clock, T)
        logSystem(T)
        extendStatistics(T)

        data <- toJSON(statisticsPooled)
        session$sendCustomMessage("update-graph-pooled", data)
        
        doctorCarePooled[type] <<- NA
    }
    
    ##################################
    ## END FUNCTIONS FOR SIMULATION ##
    ##################################
    
    ## ---------------------------- ##
    
    ##########################
    ## START SIMULATION RUN ##
    ##########################
    
    # simulation initialization
    addArrivalEvent(1) # 2nd argument was "X" before
    addArrivalEvent(2) # "Y"
    scheduledCount <- 2
    
    # simulation main loop
    observe({
        # invalidateLater(timeUntilNextEvent * progressionRate)
        
        # A Phase
        clock <<- as.numeric(futureEventList[1, 1])
        #currentlyPooled <- pooled
        
        while (futureEventList[1, 1] == clock) { # some bug here where the FEL can be empty?
            event <- futureEventList[1,]
            futureEventList <<- futureEventList[-c(1), ] # remove current event from FEL
            print(paste0("Time: ", clock))
            
            # B Phase
            if (event[1, ]$event == "arrival") {
                modelArrival(event[1, ]$type)
            } else if (event[1, ]$event == "departure" && event[1, ]$pooled == F) {
                modelDepartureUnpooled(event[1, ]$type)
            } else if (event[1, ]$event == "departure" && event[1, ]$pooled) {
                modelDeparturePooled(event[1, ]$type)
            } else {
                print("ERROR: undefined event.")
                quit("no")
            }
        }
        
        
        # C Phase
        if (is.na(doctorCareUnpooled['X']) &&
            isPatientWaiting(1, F)) {
            dequeue(1, F) # "X" before
            addDepartureEvent(1, F) # schedule next departure unpooled
        }
        if (is.na(doctorCareUnpooled['Y']) &&
            isPatientWaiting(2, F)) {
            dequeue(2, F) # "Y" before
            addDepartureEvent(2, F) # schedule next departure unpooled
        }
        if (is.na(doctorCarePooled['X']) &&
            isPatientWaiting(1, T)) {
            dequeue(1, T) # "X" before
            addDepartureEvent(1, T) # schedule next departure pooled
        }
        if (is.na(doctorCarePooled['Y']) &&
            isPatientWaiting(2, T)) {
            dequeue(2, T) # "Y" before
            addDepartureEvent(2, T) # schedule next departure pooled
        }
        
        
        timeUntilNextEvent <<- futureEventList[1, 1] - clock
        print(paste0("Until next: ", timeUntilNextEvent))
        if (input$play) {
            timing <- timeUntilNextEvent * progressionRate
            # print(paste0("Timing: ", progressionRate))
            invalidateLater(timing)
        } else {
            #print(patientStats)
        }
        
        # send state of system to JS
        gettingMedical <-
            data.frame(id = as.integer(c(doctorCareUnpooled['X'], doctorCareUnpooled['Y'])), type = as.integer(c(-1, -2)))
        gettingMedical <- na.omit(gettingMedical)
        data <- rbind(gettingMedical, waitingQueueUnpooled)
        data <- toJSON(data)
        session$sendCustomMessage("update-animation-unpooled", data)
        
        gettingMedical <-
            data.frame(id = as.integer(c(doctorCarePooled['X'], doctorCarePooled['Y'])), type = as.integer(c(-1, -2)))
        gettingMedical <- na.omit(gettingMedical)
        data <- rbind(gettingMedical, waitingQueuePooled)
        data <- toJSON(data)
        session$sendCustomMessage("update-animation-pooled", data)
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
        
        output$performancePooled <- renderText("")
        output$performanceUnpooled <- renderText("")
    })
    
    probi <- function(type) {
        arrivalRate[type] / (arrivalRate['X'] + arrivalRate['Y'])
    }
    
    observeEvent(input$showPerformanceUnpooled, {
        rho1 <- arrivalRate['X'] / serviceRate['X']
        rho2 <- arrivalRate['Y'] / serviceRate['Y']
        
        EWq1 <- 0.5 * (rho1)^2 / (1 - rho1) / arrivalRate['X'] * 60
        EWq2 <- 0.5 * (rho2)^2 / (1 - rho2) / arrivalRate['Y'] * 60
        
        EWqA <- probi('X') * EWq1 + probi('Y') * EWq2
        
        out <- renderText(paste0("Mean waiting time::: green patient: ", round(EWq1, 2), ", blue patient: ", round(EWq2, 2), ", average patient: ", round(EWqA, 2)))
        output$performanceUnpooled <- out
    })
    
    observeEvent(input$showPerformancePooled, {
        k_a <- arrivalRate['X'] / arrivalRate['Y']
        k_s <- serviceRate['X'] / serviceRate['Y']
        
        rho1 <- arrivalRate['X'] / serviceRate['X']
        rho2 <- arrivalRate['Y'] / serviceRate['Y']
        
        rho_ <- (k_a + k_s) / (2 * k_a) * rho1
        tau_ <- (k_a + k_s) / (k_a + 1) * (1 / serviceRate['X'])
        c2_mix <- (k_a * (k_s - 1)^2) / (k_a + k_s)^2
        
        EWqP <- 0.5 * (1 + c2_mix) * (tau_ * rho_^2) / (1 - rho_^2) * 60
        
        out <- renderText(paste0("Mean waiting time average patient: ", round(EWqP, 2)))
        output$performancePooled <- out
    })
}

##################
### END SERVER ###
##################


shinyApp(ui, server)