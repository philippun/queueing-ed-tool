library(shiny)

################
### START UI ###
################

settings <- function() {
    tabPanel(
        "Settings",
        h3("Patients"),
        sliderInput(
            "arrivalRateX",
            "Arrival rate X:",
            min = 1,
            max = 20,
            value = 9
        ),
        sliderInput(
            "arrivalRateY",
            "Arrival rate Y:",
            min = 1,
            max = 20,
            value = 9
        ),
        h3("Hospitals"),
        checkboxInput("pooled",
                      "Pool queues",
                      value = TRUE),
        sliderInput(
            "serviceRateX",
            "Service rate X:",
            min = 1,
            max = 20,
            value = 11
        ),
        sliderInput(
            "serviceRateY",
            "Service rate Y:",
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
    sidebarLayout(sidebarPanel(
        checkboxInput("play",
                      "Play/Pause",
                      value = TRUE),
        tabsetPanel(settings(),
                    scenarios()),
        width = 3
    ),
    mainPanel())
}

ui <- navbarPage(
    "Queueing Education Tool",
    selected = "App",
    tabPanel("App", app()),
    tabPanel("About", includeMarkdown("about.md"))
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
    doctorIdle <- c(X = TRUE, Y = FALSE)
    
    
    ####################################
    ## START FUNCTIONS FOR SIMULATION ##
    ####################################
    
    # generate random number from exp dist and truncate
    genRand <- function(event, type) {
        if (event == "arrival") {
            rate <-
                arrivalRate[type] # can be seen as avg patients arriving per hour
        } else if (event == "departure") {
            rate <- serviceRate[type]
        } else {
            print("ERROR: event was neither arrival nor departure.")
        }
        
        trunc <- 4
        num <- rexp(1, rate = rate)
        if (num > (trunc * 1 / rate)) {
            (trunc * 1 / rate)
        } else {
            num
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
            waitingQueue <<- waitingQueue[-c(1), ]
        } else {
            for (i in 1:nrow(waitingQueue)) {
                if (waitingQueue[i, "type"] == type) {
                    # print(paste0("Took in patient of type ", waitingQueue[i,2]))
                    waitingQueue <<- waitingQueue[-c(i), ]
                    break
                }
            }
        }
    }
    
    # check if a patient is waiting
    # considers if queues are currently pooled or not
    isPatientWaiting <- function(type, currentlyPooled) {
        if (currentlyPooled) {
            # check if doctor should care for patient type
            nrow(waitingQueue) > 0
        } else {
            any(waitingQueue == type)
        }
    }
    
    # patient arrival
    modelArrival <- function(type) {
        arrivalCount <<- arrivalCount + 1
        enqueue(type)
        
        if (scheduledCount < arrivalMax) {
            addEvent("arrival", type) # schedule next arrival
            scheduledCount <<- scheduledCount + 1
        }
    }
    
    # patient departure
    modelDeparture <- function(type) {
        doctorIdle[type] <<- TRUE
        # if (type == "X") {
        #     doctorXIdle <<- TRUE
        # } else {
        #     doctorYIdle <<- TRUE
        # }
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
        if (doctorIdle['X'] &&
            isPatientWaiting("X", currentlyPooled)) {
            doctorIdle['X'] <<- FALSE
            dequeue("X", currentlyPooled)
            addEvent("departure", "X") # schedule next departure
        }
        if (doctorIdle['Y'] &&
            isPatientWaiting("Y", currentlyPooled)) {
            doctorIdle['Y'] <<- FALSE
            dequeue("Y", currentlyPooled)
            addEvent("departure", "Y") # schedule next departure
        }
        
        
        timeUntilNextEvent <<- futureEventList[1, 1] - clock
        print(paste0("Until next: ", timeUntilNextEvent))
        if (input$play) {
            invalidateLater(timeUntilNextEvent * progressionRate)
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