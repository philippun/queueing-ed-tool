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
    # initial settings
    clock <- 0
    arrivalCount <- 0
    scheduledCount <- 0
    arrivalMax <- 500
    pooled <- TRUE
    progressionRate <- 1000
    
    # set up waiting queue
    waitingQueue <- data.frame(matrix(ncol = 2, nrow = 0))
    colnames(waitingQueue) <- c('id', 'type')
    
    # set up future event list (FEL)
    futureEventList <- data.frame(time = double(), type = character())
    
    # set up idle doctors 
    doctorXIdle <- TRUE
    doctorYIdle <- TRUE
    
    # generate random number from exp dist and truncate
    genRand <- function() {
        num <- rexp(1)
        if (num > 4) {
            4
        } else {
            num
        }
    }
    
    # add a new event to the Future Event List
    addEvent <- function(type) {
        newEvent <- data.frame(time = as.double(clock + genRand()), type = c(type))
        futureEventList <<- rbind(futureEventList, newEvent)
        futureEventList <<- futureEventList[order(futureEventList$time), ]
    }
    
    # enqueues a new patient arrival
    enqueue <- function(type) {
        newPatient <- c(arrivalCount, type)
        newPatient <- data.frame(matrix(newPatient, ncol = 2, nrow = 1))
        colnames(newPatient) <- c('id', 'type')
        waitingQueue <<- rbind(waitingQueue, newPatient)
    }
    
    # dequeues a patient
    # considers if queues are currently pooled or not
    dequeue <- function(type, currentlyPooled) {
        if (currentlyPooled) {
            # print(paste0("Took in patient of type ", waitingQueue[1,2]))
            waitingQueue <<- waitingQueue[-c(1),]
        } else {
            for (i in 1:nrow(waitingQueue)) {
                if (waitingQueue[i, "type"] == type) {
                    # print(paste0("Took in patient of type ", waitingQueue[i,2]))
                    waitingQueue <<- waitingQueue[-c(i),]
                    break
                }
            }
        }
    }
    
    # check if a patient is waiting
    # considers if queues are currently pooled or not
    isPatientWaiting <- function(type, currentlyPooled) {
        if (currentlyPooled) { # check if doctor should care for patient type
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
            addEvent(paste0("arrival", type)) # schedule next arrival
            scheduledCount <<- scheduledCount + 1
        }
    }
    
    # patient departure
    modelDeparture <- function(type) {
        if (type == "X") {
            doctorXIdle <<- TRUE
        } else {
            doctorYIdle <<- TRUE
        }
    }
    
    # simulation initialization
    addEvent("arrivalX")
    addEvent("arrivalY")
    scheduledCount <- 2
    timeUntilNextEvent <- as.numeric(futureEventList[1,1]) - clock
    
    # main loop
    observe({
        invalidateLater(timeUntilNextEvent * progressionRate)
        
        # A Phase
        event <- futureEventList[1, ]
        # print(paste0("Time: ", event[1,1], "; Type: ", event[1,2]))
        futureEventList <<- futureEventList[-c(1),]
        clock <<- as.numeric(event[1,1])
        # print(clock)
        # print(futureEventList)
        
        # B Phase
        if (event[1,2] == "arrivalX") {
            modelArrival("X")
            print("Patient of type X arrived")
        } else if (event[1,2] == "arrivalY") {
            modelArrival("Y")
            print("Patient of type Y arrived")
        } else if (event[1,2] == "departureX") {
            modelDeparture("X")
            print("Patient of type X left")
        } else if (event[1,2] == "departureY") {
            modelDeparture("Y")
            print("Patient of type Y left")
        }
        
        # C Phase
        currentlyPooled <- pooled
        if (doctorXIdle && isPatientWaiting("X", currentlyPooled)) {
            doctorXIdle <<- FALSE
            # print("Doctor X calls patient in!")
            dequeue("X", currentlyPooled)
            addEvent("departureX") # schedule next departure
        }
        if (doctorYIdle && isPatientWaiting("Y", currentlyPooled)) {
            doctorYIdle <<- FALSE
            # print("Doctor Y calls patient in!")
            dequeue("Y", currentlyPooled)
            addEvent("departureY") # schedule next departure
        }
        
        
        timeUntilNextEvent <- as.numeric(futureEventList[1,1]) - clock
    })
    
}

shinyApp(ui, server)