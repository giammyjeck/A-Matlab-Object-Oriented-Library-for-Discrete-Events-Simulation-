%% main_MM1.m

clc; clear;close all; rng(123);
fclose('all');


%% Parametri
   
currentConfig = struct(...
    'lambda', 2, ...% rate di arrivo (clienti/unità di tempo)
    'mu', 1.4);% rate di servizio

values = containers.Map;
values('lambda') = [2, 2.5];
values('mu')  = [1.4, 1.8];

%% Creazione Entità

% Entità Queue e Server
queue  = TransactionBasedEntity('Queue', [], currentConfig);
server = ResourceBasedEntity('Server', 1,[],currentConfig); 

entities = {queue, server};

%% Inizializziamo le classi di SimulatorManager:

t0 = exprnd(queue.info.lambda);
e = Events('Arrival', t0, struct(), queue);
eventList = EventsList(entities, {e});  % coda eventi

scenarioGen = ScenarioGenerator(currentConfig,10,10000,values);

StopThreshold = struct('toServe',10000);
stats = Statistics(StopThreshold);             
stats.contatori = struct('toServe',0); % raccoglitore dati

%% Registra gli handle
% entrambi gli handle fanno riferimento all'entità queue, infatti l'entità 
% server si sarebbe potuta evitare per semplicità, adattando gli handle,
% qui però ho voluto controllare il funzionamento di alcuni metodi

% Handler per gli arrivi
queue.registerHandler('Arrival', @(self, ev) ...
    arrivalHandler(self, ev, stats, eventList, server));

% Handler per le partenze
queue.registerHandler('Departure', @(self, ev) ...
    departureHandler(self, ev, stats, eventList, server));

%% Avvia

simManager = SimulatorManager(eventList, scenarioGen, stats);
 
simManager.startSimulation();



%% --- LOCAL HANDLERS -----

function arrivalHandler(self,event,stats, eventList, server)
    
    t = event.time;
    
    % Registro la lunghezza prima dell arrivo
    stats.recordQueueLength(self.name, t, self.queueLength());
    
    % Metto il cliente in coda
    self.enqueue(t);
    
    % Se il server è libero, lo alloco e genero il service time 
    if server.isAvailable(1)
        server.allocate(1);
        
        arrTime = self.dequeue();
        stats.recordWaitTime(self.name, t - arrTime); 
        
        servTime = exprnd(server.info.mu);
        stats.recordServiceTime(self.name, servTime);
        eventList.addEvent( Events('Departure', t + servTime, [], self) );
    end

    % genero il prossimo arrivo
    tNext = t + exprnd(self.info.lambda);
    eventList.addEvent( Events('Arrival', tNext, [], self) );

end


function departureHandler(self, event, stats, eventList, server)
    t = event.time;
    
    % Registra lunghezza della coda prima della departure
    stats.recordQueueLength(self.name, t, self.queueLength());
    
    % Rilascia il server
    server.release(1);
    stats.record('toServe'); % Incrementa contatore clienti serviti

    
    % Se coda non vuota, servi il prossimo cliente
    if ~self.isQueueEmpty()
        arrTime = self.dequeue();
        stats.recordWaitTime(self.name, t - arrTime);
        
        server.allocate(1);
        
        servTime = exprnd(server.info.mu);
        stats.recordServiceTime(self.name, servTime);
        
        eventList.addEvent( Events('Departure', t + servTime, [], self) );
    end
end
