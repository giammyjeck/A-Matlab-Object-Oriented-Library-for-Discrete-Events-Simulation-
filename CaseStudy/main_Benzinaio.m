clc
close all
clear
rng(26)

fclose('all');
delete('simulation_report.txt');

 %% Settiamo i parametri e i livelli su cui effetturare la simulazione
 % Per ogni parametro in currentConfig possiamo scegliere dei livelli di
 % simulazione, ScenarioGenerator costruisce un piano degli esperimenti
 % generando uno scenario per ogni combinazione di livelli

currentConfig = struct(...
    'servRatePump', 5, ...
    'servRate', 1, ...
    'ArrivalRate', 2, ...
    'Stagionalita', 0.2, ...
    'maxPlaces', 3);


values = containers.Map;
values('ArrivalRate') = [4, 5, 6];
values('servRate')    = [2, 1];
values('servRatePump') = [3.5, 5, 7];
values('Stagionalita') = [0.2, 0.5]; % vedere come viene calcolata la stag !!!


%% Costruzione delle entità

pumpsState = struct( 'AfreeExit', false, 'AalreadyPaid',false, ...
    'CfreeExit', false,'CalreadyPaid', false);
capacity = struct('A',1,'B',1,'C',1,'D',1);

pumps = ResourceBasedEntity('Pumps', capacity, pumpsState, currentConfig);
cashier = TransactionBasedEntity('Cashier', [], currentConfig);
vehicleQueue = TransactionBasedEntity('VehicleQueue',[],currentConfig); 


entities = {pumps, cashier, vehicleQueue};

%% Inizializziamo le classi di SimulatorManager:
% ListaEventi, ScenarioGenerator e Statistics

firstArrivalTime = exprnd(vehicleQueue.info.ArrivalRate);
e = Events('Arrival', firstArrivalTime, [], vehicleQueue);
eventsList = EventsList(entities, {e});


sg = ScenarioGenerator(currentConfig, 100, 1440, values);



stopThreshold = struct('toServe',1000, 'lost',inf); 
% possiamo definire dei criteri di stop simulazione anche al raggiungimento
% di una certa statistica
stats = Statistics(stopThreshold);
stats.contatori = struct('toServe',0, 'lost',0);



%% Registriamo gli handle per gestione eventi
% ogni evento viene assegnato ad una classe che ha il compito di gestirlo
% secondo il modello che stiamo simulando

vehicleQueue.registerHandler('Arrival', ...
    @(self,ev) onArrival(self, ev, stats, eventsList,pumps,sg));

cashier.registerHandler('PaymentCompleted', ...
    @(self,ev) onPaymentCompleted(self, ev, stats, eventsList,pumps, vehicleQueue));

pumps.registerHandler('RefuelOnA', @(self,ev) onRefuelOn(self, ev, stats, eventsList, cashier));
pumps.registerHandler('RefuelOnB', @(self,ev) onRefuelOn(self, ev, stats, eventsList, cashier));
pumps.registerHandler('RefuelOnC', @(self,ev) onRefuelOn(self, ev, stats, eventsList, cashier));
pumps.registerHandler('RefuelOnD', @(self,ev) onRefuelOn(self, ev, stats, eventsList, cashier));



%% Avviamo la simulazione

mgr = SimulatorManager(eventsList, sg, stats);


mgr.startSimulation();





%% ─── Definizione degli Handler  ───
% eventualmente in un file separato e si possono introdurre brevi funzioni che
% evitano i blocchi ripetitivi per la gestione di casi simili

function onArrival(self, event, stats, eventsList, pumps,scenario)
    % Quando arriva una nuova macchina prova a mettersi in coda, (accodo 
    % una struct che memorizza tempo di ingresso nel sistema e il lato della
    % bocchetta).
    % Se la coda è vuota e c'è disponibilità, viene indirizzata subito ad 
    % una pompa libera.
    % Altrimenti mi metto in fondo, se non sono esauriti i posti auto,
    % in tal caso segnalo il veicolo come lost.
    % Genero il prossimo arrivo indipendentemente da quello che è successo.

    clock = event.time;
    if self.queueLength() < self.info.maxPlaces
        dx = rand() < 0.5;  
        self.enqueue(struct( ...
            'arrivalTimeInSystem', clock, ...
            'latoDx', dx));
    else
        stats.record('lost');
        fprintf('ho perso una macchina \n')
    end
    % registro la lunghezza
    stats.recordQueueLength('vehicleQueue', clock, self.queueLength());

    if self.queueLength() == 1
        dx = self.queue{1}.latoDx;

        if dx == 1
            if  pumps.isAvailable(1,'B') && pumps.isAvailable(1,'A') % per transito 
                pumps.allocate(1,'B'); % alloco la macchina alla pompa B
                stats.recordResourceUsage('Pumps',clock,pumps.busy);
                % genero un tempo di servizio per la pompaB
                nextServB = clock + exprnd(pumps.info.servRatePump);
                data = self.dequeue();              
                stats.recordWaitTime('vehicleQueue',clock- data.arrivalTimeInSystem);
                stats.recordQueueLength('vehicleQueue', clock,self.queueLength());
                eventsList.addEvent(Events('RefuelOnB', nextServB, data.arrivalTimeInSystem, pumps));
                pumps.state.AfreeExit = false;

            elseif pumps.isAvailable(1,'A')
                pumps.allocate(1,'A');      
                stats.recordResourceUsage('Pumps',clock,pumps.busy);
                nextServA = clock + exprnd(pumps.info.servRatePump);
                data = self.dequeue();              
                stats.recordWaitTime('vehicleQueue',clock- data.arrivalTimeInSystem);
                stats.recordQueueLength('vehicleQueue', clock,self.queueLength());
                eventsList.addEvent(Events('RefuelOnA', nextServA, data.arrivalTimeInSystem, pumps));
            end
        else
            if pumps.isAvailable(1,'D') && pumps.isAvailable(1,'C') % per transito
                pumps.allocate(1,'D');      
                stats.recordResourceUsage('Pumps',clock,pumps.busy);
                nextServD = clock + exprnd(pumps.info.servRatePump);
                data = self.dequeue();              
                stats.recordWaitTime('vehicleQueue',clock- data.arrivalTimeInSystem);
                stats.recordQueueLength('vehicleQueue', clock,self.queueLength());
                eventsList.addEvent(Events('RefuelOnD', nextServD, data.arrivalTimeInSystem, pumps));
                pumps.state.CfreeExit = false;
            elseif pumps.isAvailable(1,'C')
                pumps.allocate(1,'C');      
                stats.recordResourceUsage('Pumps',clock,pumps.busy);
                nextServC = clock + exprnd(pumps.info.servRatePump);
                data = self.dequeue();              
                stats.recordWaitTime('vehicleQueue',clock- data.arrivalTimeInSystem);
                stats.recordQueueLength('vehicleQueue', clock,self.queueLength());
                eventsList.addEvent(Events('RefuelOnC', nextServC, data.arrivalTimeInSystem, pumps));
            end
        end
    end

    % Genero sempre il prossimo arrivo al più lo perdo
    arrivalRate = scenario.getSeasonalRate(self.info.ArrivalRate, clock);
    nextArrival = clock + exprnd(arrivalRate);
    eventsList.addEvent(Events('Arrival', nextArrival,[], self));
end

function onPaymentCompleted(self, ev, stats, eventsList,pumps,vehicleQueue)

    % Prendo il primo cliente in coda cassa e lo servo, poi controllo se la
    % macchina può partire liberando il posto, in base alla posizione della
    % pompa può liberare uno o due posti.

    clock = ev.time;
    data = self.dequeue(); % servo il cliente
    pump = data.pompaProvenienza;
    stats.recordWaitTime('cashier',clock - data.tempoEntrataCashierQueue)
    stats.recordQueueLength('cashier', clock, self.queueLength());

    switch pump
        case 'B'
            pumps.release(1,'B');        
            stats.record('toServe');
            stats.recordResourceUsage('Pumps',clock,pumps.busy);
            pumps.state.AfreeExit = true;
    
            if pumps.state.AalreadyPaid
                pumps.release(1,'A');
                stats.recordResourceUsage('Pumps',clock,pumps.busy);
                pumps.state.AalreadyPaid = false;
                stats.record('toServe');
            end
    
        case 'A'
            if pumps.state.AfreeExit
                pumps.release(1,'A');
                stats.recordResourceUsage('Pumps',clock,pumps.busy);
                pumps.state.AalreadyPaid = false;
                stats.record('toServe');
            else
                pumps.state.AalreadyPaid = true;
            end
    
        case 'D'
            pumps.release(1,'D');       
            stats.recordResourceUsage('Pumps',clock,pumps.busy);
            stats.record('toServe');
            pumps.state.CfreeExit = true;
    
            if pumps.state.CalreadyPaid
                pumps.release(1,'C');
                stats.recordResourceUsage('Pumps',clock,pumps.busy);
                pumps.state.CalreadyPaid = false;
                stats.record('toServe');
            end
    
        case 'C'
            if pumps.state.CfreeExit
                pumps.release(1,'C');
                stats.recordResourceUsage('Pumps',clock,pumps.busy);
                pumps.state.CalreadyPaid = false;
                stats.record('toServe');
            else
                pumps.state.CalreadyPaid = true;
            end
    
        otherwise
            error('caso non contemplato \n');
    end
   
    if self.queueLength() > 0
       nextPagamento = clock+exprnd(self.info.servRate);
       eventsList.addEvent(Events('PaymentCompleted',nextPagamento,[],self));
    end
    

    % Serviamo la testa finché lo è
    while ~vehicleQueue.isQueueEmpty()
        info = vehicleQueue.queue{1};      
        side = info.latoDx;   % 1 = destro, 0 = sinistro
        
        if side == 1
            % lato destro
            canB = pumps.isAvailable(1,'B') && pumps.isAvailable(1, 'A');
            canA = pumps.isAvailable(1, 'A');
            
            if canB
                chosen = 'B';
            elseif canA
                chosen = 'A';
            else
                break; % non ci sono pompe disponibili da questo lato
            end
            
        else
            % lato sinistro
            canD = pumps.isAvailable(1,'D') && pumps.isAvailable(1, 'C');
            canC = pumps.isAvailable(1, 'C');
            
            if canD
                chosen = 'D';
            elseif canC
                chosen = 'C';
            else
                break;
            end
        end
        
        info = vehicleQueue.dequeue();
        pumps.allocate(1,chosen);
        stats.recordResourceUsage('Pumps',clock,pumps.busy);
        
        servTime = exprnd(pumps.info.servRatePump);
        %servTime = unifrnd(4.5,5.5);
        eventName = ['RefuelOn' chosen];
        t = info.arrivalTimeInSystem;
        eventsList.addEvent( Events(eventName, clock + servTime, info, pumps) );
        
        stats.recordWaitTime('vehicleQueue',clock- t);
        stats.recordQueueLength('vehicleQueue',clock,vehicleQueue.queueLength());
        
    end
end

function onRefuelOn(self, ev, stats, eventsList, cashier)
    % una pompa ha completato il rifornimento benzina, aggiungo un cliente nella 
    % coda della cassa, se in cassa non c'è nessuno lo servo anche.

    clock = ev.time;
    info = struct( ...
        'tempoEntrataCashierQueue', clock, ...
        'pompaProvenienza', ev.name(end), ...
        'tempoEntrataSystem', ev.data);

    if cashier.isQueueEmpty()
        nextPayment = clock+exprnd(cashier.info.servRate);
        eventsList.addEvent(Events('PaymentCompleted',nextPayment,[],cashier));
        cashier.enqueue(info);
        stats.recordQueueLength('cashier', clock, cashier.queueLength());        
    else
        cashier.enqueue(info);
        stats.recordQueueLength('cashier', clock, cashier.queueLength());
    end

    if strcmp(ev.name(end), 'C')
        self.state.CfreeExit = self.isAvailable(1,'D');
    elseif strcmp(ev.name(end), 'A')
        self.state.AfreeExit = self.isAvailable(1,'B');
    end

end



   
