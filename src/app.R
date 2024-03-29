library(shiny)
library(jsonlite)
library(markdown)

################
### START UI ###
################

# UI elements of the settings section with a tab panel for settings itself
# and one for scenarios
settings <- function() {
    tabPanel(
        "Settings",
        h3("Hospital"),
        h4("Green Patients"),
        sliderInput(
            "arrivalRateX",
            "Arrival rate (per hour):",
            min = 1,
            max = 60,
            value = 9
        ),
        sliderInput(
            "serviceRateX",
            "Service rate (per hour):",
            min = 1,
            max = 60,
            value = 11
        ),
        h4("Blue Patients"),
        sliderInput(
            "arrivalRateY",
            "Arrival rate (per hour):",
            min = 1,
            max = 60,
            value = 9
        ),
        sliderInput(
            "serviceRateY",
            "Service rate (per hour):",
            min = 1,
            max = 60,
            value = 11
        ),
        # additional settings that are hidden by default
        a(id = "toggleAdditionalSettings", "Additional settings", href = "#"),
        shinyjs::hidden(div(
            id = "additionalSettings",
            sliderInput(
                "lastPatients",
                "Number of patients who recently finished their appointment and over which the graph statistics are calculated:",
                min = 3,
                max = 30,
                value = 20
            ),
            sliderInput(
                "truncFactor",
                "Truncation factor at which the generated inter-arrival time is bounded (in comparison to the mean):",
                min = 1,
                max = 10,
                value = 4
            )
        ))
    )
}

# content of the scenarios settings tab panel
scenarios <- function() {
    tabPanel(
        "Scenarios",
        h3("Select and click one: "),
        actionButton("scenario1", "Scenario 1 | k-factor = 10", width = "100%"),
        actionButton("scenario2", "Scenario 2 | Equal 90% utilization", width = "100%"),
        actionButton("scenario3", "Scenario 3 | Random", width = "100%")
        )
}

# overall strucutre of the app(lication) site of the educational tool
app <- function() {
    sidebarLayout(
        sidebarPanel(
            actionButton("play",
                          "Play/Pause", width = "100%"),
            actionButton("reset", "Reset", width = "100%"),
            selectInput("animation_speed",
                        "Speed:",
                        c("Slow", "Medium", "Fast"),
                        selected = "Medium"),
            tabsetPanel(id = "settings_tabs",
                        settings(),
                        scenarios()),
            width = 2),
        mainPanel(
            fluidRow(
                column(6, 
                       tags$h3("Unpooled"), 
                       actionButton("showPerformanceUnpooled", "Show Expected Waiting Times"), 
                       verbatimTextOutput("performanceUnpooled", placeholder = T), 
                       div(class="top", div(class="animation-unpooled")), 
                       div(class="bottom", div(class="graph-unpooled"))),
                column(6, 
                       tags$h3("Pooled"), 
                       actionButton("showPerformancePooled", "Show Expected Waiting Times"), 
                       verbatimTextOutput("performancePooled", placeholder = T), 
                       div(class="top", div(class="animation-pooled")), 
                       div(class="bottom", div(class="graph-pooled")))
            ),
            width = 10
        ))
}

# ui function as required by Shiny and that defines the toplevel UI
ui <- navbarPage(
    "Queueing Education Tool",
    tags$head(tags$script(src = "https://d3js.org/d3.v5.min.js"),
              tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")),
    shinyjs::useShinyjs(),
    selected = "App",
    tabPanel("App", app()),
    tabPanel("About", div(class = "markdown", includeMarkdown("about.md"))), # , includeMarkdown("about.md")
    tags$script(type = "module", src = "app.js"),
    tags$script(type = "module", src = "graph.js"),
    tags$script(type = "module", src = "animation.js")
)

#############################
### END UI / START SERVER ###
#############################

server <- function(input, output, session) {
    # constants for simulation
    queueMax <- 10
    arrivalMax <- 10000
    fastRate <- 50000
    mediumRate <- 80000
    slowRate <- 110000
    
    # initial variables
    play <- TRUE
    clock <- as.double(0)
    arrivalCountUnpooled <- 0
    arrivalCountPooled <- 0
    scheduledCount <- 0
    progressionRate <- mediumRate
    
    arrivalRate <-
        c(X = isolate(input$arrivalRateX),
          Y = isolate(input$arrivalRateY))
    serviceRate <-
        c(X = isolate(input$serviceRateX),
          Y = isolate(input$serviceRateY))
    lastPatients <- isolate(input$lastPatients)
    truncFactor <- isolate(input$truncFactor)
    
    # set up waiting queues and future event list (FEL)
    waitingQueueUnpooled <- data.frame(id = integer(), type = integer())
    waitingQueuePooled <- data.frame(id = integer(), type = integer())
    futureEventList <-
        data.frame(time = double(),
                   event = character(),
                   type = integer(),
                   pooled = logical())
    
    # vector for saving which patient is currently at which doctor; set up idle doctors
    doctorOfficesUnpooled <-
        data.frame(id = as.integer(c(NA, NA)), type = as.integer(c(NA, NA)))
    doctorOfficesPooled <-
        data.frame(id = as.integer(c(NA, NA)), type = as.integer(c(NA, NA)))
    
    
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
            patientStatsPooled <<- tail(patientStatsPooled, 50) # privacy regulations
        } else {
            patientStatsUnpooled <<- rbind(patientStatsUnpooled, patient)
            patientStatsUnpooled <<- tail(patientStatsUnpooled, 50) # privacy regulations
        }
    }
    
    # adds a time of a specific patient to a specific column
    logPatientTime <- function(id, col, time, pooled) {
        if (pooled) {
            patientStatsPooled[patientStatsPooled$id == id, col] <<- time
        } else {
            patientStatsUnpooled[patientStatsUnpooled$id == id, col] <<- time
        }
        
    }
    
    # calculates the average waiting time of all patients of a specific type
    # or all patients
    calcAvgWaitingTime <- function(patientType = "", pooled) { 
        if (pooled) {
            relevantData <- na.omit(patientStatsPooled)
        } else {
            relevantData <- na.omit(patientStatsUnpooled)
        }
        
        
        if (patientType != "") {
            relevantData <- subset(relevantData, type == patientType)
        }
        
        relevantData <- tail(relevantData, lastPatients) # last e.g. 20 completed patients
        
        if (nrow(relevantData) > 0) {
            relevantTime <- relevantData$startMedical - relevantData$arrivalTime
            mean(relevantTime)
        } else {
            0
        }
        
    }
    
    # calculated the current queue length of a specific patient type in either
    # unpooled or pooled system
    calcQueueLength <- function(patientType, pooled) {
        if (pooled) {
            nrow(waitingQueuePooled)
        } else {
            nrow(subset(waitingQueueUnpooled, type == patientType))
        }
    }
    
    # adds statistics of either pooled or unpooled system to the logs
    logSystem <- function(pooled) {
        if (pooled) {
            currentSystemPooled <- data.frame(
                time = clock,
                queuedPatientsX = calcQueueLength(1, F),
                queuedPatientsY = calcQueueLength(2, F)
            )
            systemStatsPooled <<- rbind(systemStatsPooled, currentSystemPooled)
            systemStatsPooled <<- tail(systemStatsPooled, 50)
        } else {
            currentSystemUnpooled <- data.frame(
                time = clock,
                queuedPatientsX = calcQueueLength(1, F),
                queuedPatientsY = calcQueueLength(2, F)
            )
            systemStatsUnpooled <<- rbind(systemStatsUnpooled, currentSystemUnpooled)
            systemStatsUnpooled <<- tail(systemStatsUnpooled, 50)
        }
    }
    
    # calculated average patients in queue of either pooled or unpooled system 
    # from already collected statistics
    calcAvgPatientsInQueue <- function(pooled) {
        if (pooled) {
            queuedPatients <-
                systemStatsPooled$queuedPatientsX + systemStatsPooled$queuedPatientsY
            queuedPatients <- tail(queuedPatients, lastPatients)
            mean(queuedPatients)
        } else {
            queuedPatients <-
                systemStatsUnpooled$queuedPatientsX + systemStatsUnpooled$queuedPatientsY
            queuedPatients <- tail(queuedPatients, lastPatients)
            mean(queuedPatients)
        }
    }
    
    # extends all statistics of either pooled or unpooled system with the averages
    extendStatistics <- function(pooled) {
        newRow <- data.frame(
            avgWaitingTimeX = calcAvgWaitingTime(1, pooled),
            avgWaitingTimeY = calcAvgWaitingTime(2, pooled),
            avgPatientsInQueue = calcAvgPatientsInQueue(pooled)
        )
        
        if (pooled) {
            statisticsPooled <<- rbind(statisticsPooled, newRow)
            statisticsPooled <<- tail(statisticsPooled, 50)
        } else {
            statisticsUnpooled <<- rbind(statisticsUnpooled, newRow)
            statisticsUnpooled <<- tail(statisticsUnpooled, 50)
        }
        
    }
    
    
    ####################################
    ## START FUNCTIONS FOR SIMULATION ##
    ####################################
    
    # generate random number from exp dist and truncated at 4 times mean
    genInterArrivalTime <- function(type) {
        rate <- arrivalRate[type]
        
        trunc <- truncFactor
        num <- rexp(1, rate = rate)
        if (num > (trunc * 1 / rate)) {
            (trunc * 1 / rate)
        } else {
            num
        }
    }
    
    # add a new arrival event to the Future Event List
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
    
    # add a new departure even to the FEL
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
    
    # enqueues a newly arrived patient to unpooled system
    enqueueUnpooled <- function(type) {
        newPatient <- c(arrivalCountUnpooled, type)
        newPatient <-
            data.frame(matrix(newPatient, ncol = 2, nrow = 1))
        colnames(newPatient) <- c('id', 'type')
        waitingQueueUnpooled <<- rbind(waitingQueueUnpooled, newPatient)
    }
    
    # enqueues a newly arrived patient to pooled system
    enqueuePooled <- function(type) {
        newPatient <- c(arrivalCountPooled, type)
        newPatient <-
            data.frame(matrix(newPatient, ncol = 2, nrow = 1))
        colnames(newPatient) <- c('id', 'type')
        waitingQueuePooled <<- rbind(waitingQueuePooled, newPatient)
    }
    
    # dequeues a patient from unpooled system 
    dequeueUnpooled <- function(doctor) {
        for (i in 1:nrow(waitingQueueUnpooled)) {
            if (waitingQueueUnpooled[i, "type"] == doctor) {
                # print(paste0("Took in patient of type ", waitingQueue[i,2]))
                
                patientId <- waitingQueueUnpooled[i, 'id']
                patientType <- waitingQueueUnpooled[i, 'type']
                doctorOfficesUnpooled[doctor, 'id'] <<- patientId
                doctorOfficesUnpooled[doctor, 'type'] <<- patientType
                waitingQueueUnpooled <<- waitingQueueUnpooled[-c(i), ]
                logPatientTime(patientId, "startMedical", clock, F)
                break
            }
        }
    }
    
    # dequeues a patient from pooled system
    dequeuePooled <- function(doctor) {
        patientId <- waitingQueuePooled[1, 'id']
        patientType <- waitingQueuePooled[1, 'type']
        doctorOfficesPooled[doctor, 'id'] <<- patientId
        doctorOfficesPooled[doctor, 'type'] <<- patientType
        waitingQueuePooled <<- waitingQueuePooled[-c(1), ] #changed into Pooled
        logPatientTime(patientId, "startMedical", clock, T)
    }
    
    # check if a patient is waiting in unpooled system
    isPatientWaitingUnpooled <- function(type) {
        any(waitingQueueUnpooled$type == type)
    }
    
    # checks if a patient is waiting in pooled system
    isPatientWaitingPooled <- function() {
        nrow(waitingQueuePooled) > 0
    }
    
    # executes all necessary things for patient arrival
    modelArrival <- function(type) {
        
        if (calcQueueLength(type, F) < queueMax) {
            arrivalCountUnpooled <<- arrivalCountUnpooled + 1
            enqueueUnpooled(type)
            logPatient(arrivalCountUnpooled, type, F)
            logPatientTime(arrivalCountUnpooled, "arrivalTime", clock, F)
        }
        
        if (calcQueueLength(type, T) < 2 * queueMax) {
            arrivalCountPooled <<- arrivalCountPooled + 1
            enqueuePooled(type)
            logPatient(arrivalCountPooled, type, T)
            logPatientTime(arrivalCountPooled, "arrivalTime", clock, T)
        }
        
        if (scheduledCount < arrivalMax) {
            addArrivalEvent(type) # schedule next arrival
            scheduledCount <<- scheduledCount + 1
        }
        
    }
    
    # executes all necessary things for patient departure in unpooled system
    modelDepartureUnpooled <- function(doctor) {
        logPatientTime(doctorOfficesUnpooled[doctor, 'id'], "endMedical", clock, F)
        logSystem(F)
        extendStatistics(F)
        
        data <- toJSON(statisticsUnpooled)
        session$sendCustomMessage("update-graph-unpooled", data)
        
        doctorOfficesUnpooled[doctor, 'id'] <<- NA
        doctorOfficesUnpooled[doctor, 'type'] <<- NA
    }
    
    # executes all necessary things for patient departure in pooled system
    modelDeparturePooled <- function(doctor) {
        logPatientTime(doctorOfficesPooled[doctor, 'id'], "endMedical", clock, T)
        logSystem(T)
        extendStatistics(T)

        data <- toJSON(statisticsPooled)
        session$sendCustomMessage("update-graph-pooled", data)
        
        doctorOfficesPooled[doctor, 'id'] <<- NA
        doctorOfficesPooled[doctor, 'type'] <<- NA
    }
    
    ##################################
    ## END FUNCTIONS FOR SIMULATION ##
    ##################################
    
    ## ---------------------------- ##
    
    ##########################
    ## START SIMULATION RUN ##
    ##########################
    
    # simulation initialization
    addArrivalEvent(1) # add arrival of type 1
    addArrivalEvent(2) # add arrival of type 2
    scheduledCount <- 2
    
    # simulation main loop
    observe({
        # invalidateLater(timeUntilNextEvent * progressionRate)
        
        # A Phase of advancing clock
        clock <<- as.numeric(futureEventList[1, 1])
        
        # exectute all B events scheduled at current time
        while (futureEventList[1, 1] == clock) {
            event <- futureEventList[1,]
            futureEventList <<- futureEventList[-c(1), ] # remove current event from FEL
            print(
                paste0(
                    "Time: ",
                    clock * 60,
                    " | System (pooled?): ",
                    event[1,]$pooled,
                    " | B-Event: ",
                    event[1,]$event,
                    " | Type: ",
                    event[1,]$type
                )
            )
            
            # B Phase | model the specific event
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
        # check if doctor 1 in unpooled system is idle and patient waiting
        if (is.na(doctorOfficesUnpooled[1, 'id']) &&
            isPatientWaitingUnpooled(1)) {
            dequeueUnpooled(1) # "X" before
            addDepartureEvent(1, pool = F) # schedule next departure unpooled
        }
        # check if doctor 2 in unpooled system is idle and patient waiting
        if (is.na(doctorOfficesUnpooled[2, 'id']) &&
            isPatientWaitingUnpooled(2)) {
            dequeueUnpooled(2) # "Y" before
            addDepartureEvent(2, pool = F) # schedule next departure unpooled
        }
        # check if doctor 1 in pooled system is idle and patient waiting
        if (is.na(doctorOfficesPooled[1, 'id']) &&
            isPatientWaitingPooled()) {
            dequeuePooled(1) # "X" before
            addDepartureEvent(1, pool = T) # schedule next departure pooled
        }
        # check if doctor 2 in pooled system is idle and patient waiting
        if (is.na(doctorOfficesPooled[2, 'id']) &&
            isPatientWaitingPooled()) {
            dequeuePooled(2) # "Y" before
            addDepartureEvent(2, pool = T) # schedule next departure pooled
        }
        
        # calculate time till next event and schedule execution of the overall
        # reactive function
        timeUntilNextEvent <<- futureEventList[1, 1] - clock
        input$play
        if (play) { # if paused then do not schedule next execution
            timing <- timeUntilNextEvent * progressionRate
            invalidateLater(timing)
        }
        
        # send state of unpooled system to JS for animation
        gettingMedical <-
            data.frame(id = as.integer(c(
                doctorOfficesUnpooled[1, 'id'], doctorOfficesUnpooled[2, 'id']
            )), type = as.integer(c(
                doctorOfficesUnpooled[1, 'type'], doctorOfficesUnpooled[2, 'type']
            )))
        data <- rbind(gettingMedical, waitingQueueUnpooled)
        data <- toJSON(data)
        session$sendCustomMessage("update-animation-unpooled", data)
        
        # send state of pooled system to JS for animation
        gettingMedical <-
            data.frame(id = as.integer(c(
                doctorOfficesPooled[1, 'id'], doctorOfficesPooled[2, 'id']
            )), type = as.integer(c(
                doctorOfficesPooled[1, 'type'], doctorOfficesPooled[2, 'type']
            )))
        data <- rbind(gettingMedical, waitingQueuePooled)
        data <- toJSON(data)
        session$sendCustomMessage("update-animation-pooled", data)
    })
    
    ########################
    ## END SIMULATION RUN ##
    ########################
    
    # observer for changing the run speed
    observe({
        if (input$animation_speed == "Slow") {
            progressionRate <<- slowRate
            print("Speed set to slow")
        } else if (input$animation_speed == "Medium") {
            progressionRate <<- mediumRate
            print("Speed set to medium")
        } else if (input$animation_speed == "Fast") {
            progressionRate <<- fastRate
            print("Speed set to fast")
        }
    })
    
    # observer for changing the settings
    observe({
        arrivalRate['X'] <<- input$arrivalRateX
        arrivalRate['Y'] <<- input$arrivalRateY
        serviceRate['X'] <<- input$serviceRateX
        serviceRate['Y'] <<- input$serviceRateY
        pooled <<- input$pooled
        variability <<- input$variability
        lastPatients <<- input$lastPatients
        truncFactor <<- input$truncFactor
        
        output$performancePooled <- renderText("")
        output$performanceUnpooled <- renderText("")
    })
    
    # calculate probability for arrival of patient type i
    probi <- function(type) {
        arrivalRate[type] / (arrivalRate['X'] + arrivalRate['Y'])
    }
    
    # observer for outputting the performance/achievement measures unpooled
    # based on van Dijk and van der Sluis (2008)
    # these are exact results
    observeEvent(input$showPerformanceUnpooled, {
        rho1 <- arrivalRate['X'] / serviceRate['X']
        rho2 <- arrivalRate['Y'] / serviceRate['Y']
        
        EWq1 <- 0.5 * (rho1)^2 / (1 - rho1) / arrivalRate['X'] * 60
        EWq2 <- 0.5 * (rho2)^2 / (1 - rho2) / arrivalRate['Y'] * 60
        
        if (EWq1 < 0) {
            EWq1 <- Inf
        }
        if (EWq2 < 0) {
            EWq2 <- Inf
        }
        
        EWqA <- probi('X') * EWq1 + probi('Y') * EWq2
        
        out <- renderText(paste0("Green Patients: ", round(EWq1, 2), " min. | Blue Patients: ", round(EWq2, 2), " min. | Average Patients: ", round(EWqA, 2), " min."))
        output$performanceUnpooled <- out
    })
    
    # observer for outputting the performance/achievement measures pooled
    # based on van Dijk and van der Sluis (2008)
    # these are approximate results
    observeEvent(input$showPerformancePooled, {
        k_a <- arrivalRate['X'] / arrivalRate['Y']
        k_s <- serviceRate['X'] / serviceRate['Y']
        
        rho1 <- arrivalRate['X'] / serviceRate['X']
        rho2 <- arrivalRate['Y'] / serviceRate['Y']
        
        rho_ <- (k_a + k_s) / (2 * k_a) * rho1
        tau_ <- (k_a + k_s) / (k_a + 1) * (1 / serviceRate['X'])
        c2_mix <- (k_a * (k_s - 1)^2) / (k_a + k_s)^2
        
        EWqP <- 0.5 * (1 + c2_mix) * (tau_ * rho_^2) / (1 - rho_^2) * 60
        
        if (EWqP < 0) {
            EWqP <- Inf
        }
        
        out <- renderText(paste0("Average Patients: ", round(EWqP, 2), " min."))
        output$performancePooled <- out
    })
    
    # observers for clicking scenario 1
    observeEvent(input$scenario1, {
        updateSliderInput(session, "arrivalRateX", value = 5)
        updateSliderInput(session, "arrivalRateY", value = 50)
        updateSliderInput(session, "serviceRateX", value = 6)
        updateSliderInput(session, "serviceRateY", value = 60)
        updateTabsetPanel(session, "settings_tabs", "Settings")
    })
    
    # observers for clicking scenario 2
    observeEvent(input$scenario2, {
        updateSliderInput(session, "arrivalRateX", value = 27)
        updateSliderInput(session, "arrivalRateY", value = 27)
        updateSliderInput(session, "serviceRateX", value = 30)
        updateSliderInput(session, "serviceRateY", value = 30)
        updateTabsetPanel(session, "settings_tabs", "Settings")
    })
    
    # observers for clicking scenario 3
    observeEvent(input$scenario3, {
        updateSliderInput(session, "arrivalRateX", value = floor(runif(1, min=1, max=60)))
        updateSliderInput(session, "arrivalRateY", value = floor(runif(1, min=1, max=60)))
        updateSliderInput(session, "serviceRateX", value = floor(runif(1, min=1, max=60)))
        updateSliderInput(session, "serviceRateY", value = floor(runif(1, min=1, max=60)))
        updateTabsetPanel(session, "settings_tabs", "Settings")
    })
    
    # observer for the play/pause button
    observeEvent(input$play, {
        if (play) {
            play <<- FALSE
        } else {
            play <<- TRUE
        }
    })
    
    # observer for the reset button
    # if clicked, reset entire simulation and add initial events
    observeEvent(input$reset, {
        #remove all events from FEL, expel patients and delete statistics
        waitingQueueUnpooled <<- waitingQueueUnpooled[0, ]
        waitingQueuePooled <<- waitingQueuePooled[0, ]
        futureEventList <<- futureEventList[0, ]
        
        doctorOfficesUnpooled <<- data.frame(id = as.integer(c(NA, NA)), type = as.integer(c(NA, NA)))
        doctorOfficesPooled <<- data.frame(id = as.integer(c(NA, NA)), type = as.integer(c(NA, NA)))
        
        statisticsUnpooled <<-  statisticsUnpooled[0, ]
        patientStatsUnpooled <<- patientStatsUnpooled[0, ]
        systemStatsUnpooled <<- systemStatsUnpooled[0, ]
        statisticsPooled <<- statisticsPooled[0, ]
        patientStatsPooled <<- patientStatsPooled[0, ]
        systemStatsPooled <<- systemStatsPooled[0, ]
        
        arrivalCountPooled <<- 0
        arrivalCountUnpooled <<- 0
        
        #add new initial arrival events
        addArrivalEvent(1)
        addArrivalEvent(2)
        scheduledCount <- 2
    })
    
    # hide/show additional settings
    shinyjs::onclick("toggleAdditionalSettings",
                     shinyjs::toggle(id = "additionalSettings", anim = TRUE))
}

##################
### END SERVER ###
##################


shinyApp(ui, server)