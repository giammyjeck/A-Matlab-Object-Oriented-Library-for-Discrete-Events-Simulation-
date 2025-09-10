classdef TransactionBasedEntity < Entity
    %%% TRANSACTIONBASEDENTITY classe che implementa un entità di tipo
    % transactionbased, queste entità hanno sempre una coda associata,
    % gestita con i metodi di questa classe
    %
    % proprietà pubbliche:
    % - queue: cell array può contenere differenti tipi di informazioni
    %
    
    properties
        queue cell 
    end
    
    methods
        %%% Costruttore
        function obj = TransactionBasedEntity(name, initialState, info)
            obj = obj@Entity(name, 'TransactionBased', initialState, info);
            obj.queue = {};
        end
        
        %%% ENQUEUE
        % Aggiunge un elemento 'data' alla coda, in posizione terminale
        %
        function enqueue(obj, data)
            obj.queue{end+1} = data;
            fprintf('%s: Enqueued, queue length now: %d\n', obj.name, obj.queueLength());
        end
        
        %%% DEQUEUE
        % metodo che preleva il primo oggetto del cell array, e lo
        % restituisce come output
        %
        function data = dequeue(obj)
            data = obj.queue{1};
            obj.queue(1) = [];
            fprintf('%s: Dequeued, queue length now: %d\n', obj.name, obj.queueLength());
        end
        
        %%% QUEUELENGTH
        % metodo che restituisce il numero di elementi in coda
        %
        function n = queueLength(obj)
            n = numel(obj.queue);
        end
        
        %%% ISQUEUEEMPTY
        % metodo che controlla se la coda contiene elementi non vuoti
        % restituisce un boolenao, true se la coda non contiene eventi validi
        %
        function tf = isQueueEmpty(obj)
            tf = all(cellfun(@isempty, obj.queue));
        end

        %%% RESETSTATE
        % metodo che pulisce la coda inizializzando un nuovo cell array
        %
        function resetState(obj)
            resetState@Entity(obj);
            obj.queue = {};
        end

    end
end


